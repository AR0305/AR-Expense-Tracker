package com.example.ar_expense_tracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Bank SMS auto-tracking. Every UPI / card / IMPS debit triggers a bank SMS regardless of which
 * payment app was used, so this is the primary detection source.
 *
 * - Live: [BankSmsReceiver] handles `SMS_RECEIVED`.
 * - Catch-up: [catchUp] scans the inbox for bank SMS that arrived while broadcasts were blocked
 *   (e.g. HyperOS / MIUI autostart restrictions). Runs when the app starts or resumes.
 */
object BankSmsTracker {
    private const val TAG = "BankSms"

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_ENABLED = "flutter.bank_sms_tracking_enabled"
    private const val STATE_PREFS = "bank_sms_state"
    private const val KEY_LAST_SCAN = "last_scan_ts"

    /** Catch-up never looks further back than this, and prompts at most [MAX_CATCH_UP] SMS. */
    private const val MAX_CATCH_UP_AGE_MS = 2L * 24 * 60 * 60 * 1000
    private const val MAX_CATCH_UP = 15

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

    fun hasReceivePermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    fun hasReadPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    /** Called right after permission is granted: start catch-up from now, never back-fill history. */
    fun markScanStart(context: Context) {
        val prefs = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        if (prefs.getLong(KEY_LAST_SCAN, 0L) == 0L) {
            prefs.edit().putLong(KEY_LAST_SCAN, System.currentTimeMillis()).apply()
        }
    }

    /** Parses one SMS and posts the Yes / No / Edit prompt. Returns true if a prompt was shown. */
    fun process(context: Context, sender: String, body: String, timestamp: Long): Boolean {
        val parsed = BankSmsParser.parse(sender, body)
        if (parsed == null) {
            Log.d(TAG, "Ignored SMS from $sender")
            return false
        }

        val duplicate = UpiPrompt.isDuplicateAndRecord(
            context,
            reference = parsed.reference,
            bodyHash = (sender.uppercase() + body.trim()).hashCode()
        )
        if (duplicate) {
            Log.d(TAG, "Duplicate bank SMS for ${parsed.amount} (ref=${parsed.reference}), skipping")
            return false
        }

        val label = buildString {
            append(parsed.bankName)
            parsed.accountTail?.let { append(" • A/c XX").append(it) }
            append(" • ").append(parsed.channel)
        }

        // Saved as the expense note: UPI ID, reference and account for later lookup
        val note = buildList {
            parsed.vpa?.let { add("UPI ID: $it") }
            parsed.reference?.let { add("Ref: $it") }
            add(parsed.bankName + (parsed.accountTail?.let { " A/c XX$it" } ?: "") + " • ${parsed.channel}")
        }.joinToString("\n")

        Log.i(TAG, "Bank debit: ${parsed.amount} to ${parsed.payee} via ${parsed.bankName} ref=${parsed.reference}")

        UpiPrompt.show(
            context,
            UpiPrompt.DetectedTxn(
                amount = parsed.amount,
                merchant = parsed.payee,
                category = UpiPrompt.inferCategory(parsed.payee, body),
                timestamp = timestamp,
                sourcePackage = "sms:${parsed.bankName}",
                notificationId = UpiPrompt.nextNotificationId(),
                sourceLabel = label,
                note = note
            )
        )
        return true
    }

    /**
     * Prompts for bank debit SMS received since the last scan that the live receiver missed.
     * SMS already prompted live are skipped by the body-hash / reference de-dup (3-day TTL).
     */
    fun catchUp(context: Context): Int {
        if (!isEnabled(context) || !hasReadPermission(context)) return 0

        val prefs = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val lastScan = prefs.getLong(KEY_LAST_SCAN, 0L)
        if (lastScan == 0L) {
            // First run with permission: start from now, don't flood with history
            prefs.edit().putLong(KEY_LAST_SCAN, now).apply()
            return 0
        }
        val since = maxOf(lastScan, now - MAX_CATCH_UP_AGE_MS)

        var prompted = 0
        var newest = lastScan
        try {
            context.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
                "${Telephony.Sms.DATE} > ?",
                arrayOf(since.toString()),
                "${Telephony.Sms.DATE} ASC"
            )?.use { c ->
                val iAddr = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val iBody = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val iDate = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
                while (c.moveToNext() && prompted < MAX_CATCH_UP) {
                    val date = c.getLong(iDate)
                    if (date > newest) newest = date
                    val sender = c.getString(iAddr) ?: continue
                    val body = c.getString(iBody) ?: continue
                    if (process(context, sender, body, date)) prompted++
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Inbox catch-up failed", e)
        }

        prefs.edit().putLong(KEY_LAST_SCAN, maxOf(newest, lastScan)).apply()
        if (prompted > 0) Log.i(TAG, "Catch-up prompted $prompted bank SMS")
        return prompted
    }
}

/** Live bank SMS receiver (manifest-registered; SMS_RECEIVED is exempt from implicit-broadcast limits). */
class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!BankSmsTracker.isEnabled(context)) return

        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (_: Exception) {
            null
        } ?: return

        // Multi-part SMS arrive as several PDUs from the same sender: join them
        messages.groupBy { it.originatingAddress ?: "" }.forEach { (sender, parts) ->
            val body = parts.joinToString("") { it.messageBody ?: "" }
            try {
                BankSmsTracker.process(context, sender, body, System.currentTimeMillis())
            } catch (e: Exception) {
                Log.w("BankSms", "Failed to process SMS from $sender", e)
            }
        }
    }
}
