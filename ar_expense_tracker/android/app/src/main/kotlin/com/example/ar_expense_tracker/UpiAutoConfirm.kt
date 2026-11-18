package com.example.ar_expense_tracker

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import java.util.UUID

/**
 * Auto-confirm engine for detected UPI payments.
 *
 * When auto-confirm is on (`upi_auto_confirm_minutes` > 0), every Yes / No / Edit prompt is
 * backed by a "pending" record plus an AlarmManager alarm. Whichever happens first wins:
 *  - ✓ Yes            -> logs the expense now
 *  - ✕ No             -> discards it
 *  - ✏️ Edit           -> discards the pending record; the user saves it from AddExpenseScreen
 *  - swipe / clear-all -> logs the expense now
 *  - timeout alarm     -> logs the expense and replaces the prompt with a silent "added" note
 *
 * A pending record can only be claimed once ([takePending]), which prevents double inserts when
 * two of the above race each other.
 */
object UpiAutoConfirm {
    private const val TAG = "UpiAutoConfirm"

    private const val STORE_NAME = "upi_auto_confirm_store"
    private const val KEY_PREFIX = "pending_"
    private const val KEY_ADDED_PREFIX = "added_"
    private const val ADDED_TTL_MS = 24L * 60 * 60 * 1000
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_MINUTES = "flutter.upi_auto_confirm_minutes"
    private const val KEY_APPROVED_QUEUE = "flutter.pending_upi_approved_queue"

    /** Default timeout when the user has never changed the setting. 0 disables auto-confirm. */
    const val DEFAULT_MINUTES = 1L

    const val ACTION_UPI_AUTO_CONFIRM = "com.example.ar_expense_tracker.ACTION_UPI_AUTO_CONFIRM"
    const val ACTION_UPI_DISMISSED = "com.example.ar_expense_tracker.ACTION_UPI_DISMISSED"

    private val lock = Any()

    /** Reads the timeout set in Flutter Settings (`prefs.setInt` is stored as a Long). */
    fun getDelayMinutes(context: Context): Long {
        val raw = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .all[KEY_MINUTES]
        return (raw as? Number)?.toLong()?.coerceAtLeast(0L) ?: DEFAULT_MINUTES
    }

    fun savePending(
        context: Context,
        notificationId: Int,
        amount: Double,
        merchant: String,
        category: String,
        timestamp: Long,
        sourcePackage: String,
        dueAt: Long,
        note: String? = null
    ) {
        val json = JSONObject().apply {
            if (!note.isNullOrEmpty()) put("note", note)
            put("notificationId", notificationId)
            put("amount", amount)
            put("merchant", merchant)
            put("category", category)
            put("timestamp", timestamp)
            put("sourcePackage", sourcePackage)
            put("dueAt", dueAt)
        }
        synchronized(lock) {
            store(context).edit().putString(KEY_PREFIX + notificationId, json.toString()).commit()
        }
    }

    /** Atomically claims and removes a pending record. Returns null if it was already handled. */
    fun takePending(context: Context, notificationId: Int): JSONObject? = synchronized(lock) {
        val prefs = store(context)
        val key = KEY_PREFIX + notificationId
        val raw = prefs.getString(key, null) ?: return@synchronized null
        prefs.edit().remove(key).commit()
        try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    /** Drops a pending record without logging it (used by ✕ No and ✏️ Edit). */
    fun discardPending(context: Context, notificationId: Int) {
        cancelAlarm(context, notificationId)
        takePending(context, notificationId)
    }

    /** True while a prompt with this id is still waiting for an answer or its timeout. */
    fun hasPending(context: Context, notificationId: Int): Boolean = synchronized(lock) {
        store(context).contains(KEY_PREFIX + notificationId)
    }

    /**
     * Remembers that the timeout or a swipe logged this prompt, so a late ✏️ Edit tap can tell the
     * user instead of opening a pre-filled editor that would save a duplicate. Kept for 1 day.
     */
    private fun markAutoAdded(context: Context, notificationId: Int) {
        if (notificationId < 0) return
        val now = System.currentTimeMillis()
        synchronized(lock) {
            val prefs = store(context)
            val editor = prefs.edit().putLong(KEY_ADDED_PREFIX + notificationId, now)
            for ((key, value) in prefs.all) {
                if (key.startsWith(KEY_ADDED_PREFIX) && now - ((value as? Long) ?: 0L) > ADDED_TTL_MS) {
                    editor.remove(key)
                }
            }
            editor.commit()
        }
    }

    /** True if the timeout or a swipe already logged this prompt (see [markAutoAdded]). */
    fun wasAutoAdded(context: Context, notificationId: Int): Boolean = synchronized(lock) {
        store(context).contains(KEY_ADDED_PREFIX + notificationId)
    }

    fun scheduleAlarm(context: Context, notificationId: Int, dueAt: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmPendingIntent(context, notificationId)
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms() ->
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAt, pi)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAt, pi)
                else ->
                    am.setExact(AlarmManager.RTC_WAKEUP, dueAt, pi)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm denied, falling back to inexact", e)
            am.set(AlarmManager.RTC_WAKEUP, dueAt, pi)
        }
    }

    fun cancelAlarm(context: Context, notificationId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmPendingIntent(context, notificationId))
    }

    /** PendingIntent fired when the user swipes the prompt away (swipe = save). */
    fun dismissPendingIntent(context: Context, notificationId: Int): PendingIntent {
        val intent = Intent(context, UpiActionReceiver::class.java).apply {
            action = ACTION_UPI_DISMISSED
            putExtra("notificationId", notificationId)
        }
        return PendingIntent.getBroadcast(context, notificationId * 10 + 5, intent, immutableFlags())
    }

    /** Commits a pending record JSON into the approved queue (timeout, swipe or reconcile). */
    fun enqueueFromPending(context: Context, pending: JSONObject, dispatchLive: Boolean = true) {
        markAutoAdded(context, pending.optInt("notificationId", -1))
        enqueueApproved(
            context,
            amount = pending.optDouble("amount", 0.0),
            merchant = pending.optString("merchant", "UPI Expense"),
            category = pending.optString("category", "General"),
            timestamp = pending.optLong("timestamp", System.currentTimeMillis()),
            sourcePackage = pending.optString("sourcePackage", ""),
            note = pending.optString("note", "").ifEmpty { null },
            dispatchLive = dispatchLive
        )
    }

    /**
     * Appends an approved transaction to the queue Flutter drains on startup/resume, and pushes it
     * to the live Flutter engine if one is running. Flutter de-duplicates by `id`.
     */
    fun enqueueApproved(
        context: Context,
        amount: Double,
        merchant: String,
        category: String,
        timestamp: Long,
        sourcePackage: String,
        note: String? = null,
        dispatchLive: Boolean = true
    ) {
        if (amount <= 0.0) return

        val txnJson = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            if (!note.isNullOrEmpty()) put("note", note)
            put("amount", amount)
            put("merchant", merchant)
            put("category", category)
            put("timestamp", timestamp)
            put("sourcePackage", sourcePackage)
        }

        synchronized(lock) {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val existing = prefs.getString(KEY_APPROVED_QUEUE, "[]") ?: "[]"
            val queue = try {
                JSONArray(existing)
            } catch (_: Exception) {
                JSONArray()
            }
            queue.put(txnJson)
            prefs.edit().putString(KEY_APPROVED_QUEUE, queue.toString()).commit()
        }

        if (dispatchLive) {
            MainActivity.dispatchUpiExpenseApproved(txnJson.toString())
        }
    }

    /**
     * Returns the approved queue without clearing it. Flutter removes entries with
     * [removeFromApprovedQueue] only after they are saved, so a crash or a failed insert in
     * Flutter cannot lose a payment.
     */
    fun readApprovedQueue(context: Context): String = synchronized(lock) {
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(KEY_APPROVED_QUEUE, "[]") ?: "[]"
    }

    /** Removes saved transactions (by `id`) from the approved queue. Drops entries with no id. */
    fun removeFromApprovedQueue(context: Context, ids: Collection<String>) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val existing = try {
                JSONArray(prefs.getString(KEY_APPROVED_QUEUE, "[]") ?: "[]")
            } catch (_: Exception) {
                JSONArray()
            }
            val kept = JSONArray()
            for (i in 0 until existing.length()) {
                val item = existing.optJSONObject(i) ?: continue
                val id = item.optString("id", "")
                if (id.isNotEmpty() && id !in ids) kept.put(item)
            }
            prefs.edit().putString(KEY_APPROVED_QUEUE, kept.toString()).commit()
        }
    }

    /**
     * Commits every pending record whose timeout has passed (alarm lost to a reboot, or delayed by
     * Doze) and re-arms alarms for the rest. Safe to call repeatedly.
     */
    fun reconcile(context: Context, dispatchLive: Boolean = true): Int {
        val now = System.currentTimeMillis()
        val entries = synchronized(lock) { store(context).all.toMap() }
        var committed = 0

        for ((key, value) in entries) {
            if (!key.startsWith(KEY_PREFIX)) continue
            val id = key.removePrefix(KEY_PREFIX).toIntOrNull() ?: continue
            val json = try {
                JSONObject(value as? String ?: continue)
            } catch (_: Exception) {
                continue
            }
            val dueAt = json.optLong("dueAt", 0L)
            if (dueAt <= now) {
                val claimed = takePending(context, id) ?: continue
                cancelAlarm(context, id)
                enqueueFromPending(context, claimed, dispatchLive)
                showAutoAddedNotification(context, id, claimed)
                committed++
            } else {
                scheduleAlarm(context, id, dueAt)
            }
        }
        if (committed > 0) Log.i(TAG, "Reconciled $committed overdue UPI expense(s)")
        return committed
    }

    /** Replaces the prompt with a silent confirmation once the timeout logs the expense. */
    fun showAutoAddedNotification(context: Context, notificationId: Int, pending: JSONObject) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val amount = pending.optDouble("amount", 0.0)
        val merchant = pending.optString("merchant", "UPI Expense")
        val category = pending.optString("category", "General")

        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openPi = openIntent?.let {
            PendingIntent.getActivity(context, notificationId * 10 + 6, it, immutableFlags())
        }

        val builder = NotificationCompat.Builder(context, UpiPrompt.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Auto-added ${formatAmount(amount)} to $merchant")
            .setContentText("$category • No response, so it was logged automatically")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setAutoCancel(true)
        if (openPi != null) builder.setContentIntent(openPi)

        nm.notify(notificationId, builder.build())
    }

    fun formatAmount(amount: Double): String =
        if (amount % 1 == 0.0) "₹${amount.toInt()}" else "₹${String.format(Locale.US, "%.2f", amount)}"

    private fun alarmPendingIntent(context: Context, notificationId: Int): PendingIntent {
        val intent = Intent(context, UpiActionReceiver::class.java).apply {
            action = ACTION_UPI_AUTO_CONFIRM
            putExtra("notificationId", notificationId)
        }
        return PendingIntent.getBroadcast(context, notificationId * 10 + 4, intent, immutableFlags())
    }

    private fun immutableFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

    private fun store(context: Context) =
        context.getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)
}

/** Re-arms auto-confirm alarms (and commits overdue prompts) after a reboot or app update. */
class UpiBootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        try {
            UpiAutoConfirm.reconcile(context)
        } catch (e: Exception) {
            Log.w("UpiAutoConfirm", "Reconcile after boot failed", e)
        }
    }
}
