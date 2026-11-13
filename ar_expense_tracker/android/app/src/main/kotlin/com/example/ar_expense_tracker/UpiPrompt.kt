package com.example.ar_expense_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

/**
 * "Detected payment" prompt (✓ Yes / ✕ No / ✏️ Edit + auto-confirm) and de-duplication for
 * payments detected from bank SMS.
 */
object UpiPrompt {

    const val CHANNEL_ID = "upi_tracking_channel"
    const val CHANNEL_NAME = "Payment Alerts"
    const val CHANNEL_DESC = "Prompts to confirm and log detected payments"

    const val ACTION_UPI_YES = "com.example.ar_expense_tracker.ACTION_UPI_YES"
    const val ACTION_UPI_NO = "com.example.ar_expense_tracker.ACTION_UPI_NO"

    data class DetectedTxn(
        val amount: Double,
        val merchant: String,
        val category: String,
        val timestamp: Long,
        /** Source tag, "sms:<Bank name>" for bank SMS. */
        val sourcePackage: String,
        val notificationId: Int,
        /** Optional line shown under the title, e.g. "Axis Bank • A/c XX0217". */
        val sourceLabel: String? = null,
        /** Optional expense note, e.g. "UPI ID: x@ybl\nRef: 6316...". */
        val note: String? = null
    )

    private val idCounter = AtomicInteger((System.currentTimeMillis() % 50000).toInt())

    /** Unique notification id in 2000..101999 (also keys the auto-confirm pending record). */
    fun nextNotificationId(): Int = 2000 + (idCounter.incrementAndGet() and 0x7fffffff) % 100000

    // ---------------------------------------------------------------- de-duplication

    private const val DEDUP_STORE = "upi_dedup_store"
    private const val REF_TTL_MS = 3L * 24 * 60 * 60 * 1000 // 3 days
    private val dedupLock = Any()

    /**
     * Returns true if this payment was already prompted (same bank reference number or same SMS
     * body seen in the last 3 days). Otherwise records it and returns false.
     */
    fun isDuplicateAndRecord(
        context: Context,
        reference: String? = null,
        bodyHash: Int? = null
    ): Boolean = synchronized(dedupLock) {
        val prefs = context.getSharedPreferences(DEDUP_STORE, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        if (reference != null && prefs.contains("ref_$reference")) return@synchronized true
        if (bodyHash != null && prefs.contains("body_$bodyHash")) return@synchronized true

        val editor = prefs.edit()
        if (reference != null) editor.putLong("ref_$reference", now)
        if (bodyHash != null) editor.putLong("body_$bodyHash", now)
        // Prune old entries (also clears legacy "amt_*" keys)
        for ((key, value) in prefs.all) {
            val ts = value as? Long ?: continue
            if (now - ts > REF_TTL_MS || key.startsWith("amt_")) editor.remove(key)
        }
        editor.commit()
        false
    }

    // ---------------------------------------------------------------- category inference

    /** Maps merchant/text keywords to the app's default categories (see CategoryUtils). */
    fun inferCategory(merchant: String, fullText: String): String {
        val str = "${merchant.lowercase(Locale.ROOT)} ${fullText.lowercase(Locale.ROOT)}"
        fun has(vararg words: String) = words.any { str.contains(it) }

        return when {
            has("swiggy", "zomato", "cafe", "chai", "coffee", "restaurant", "starbucks", "mcdonald",
                "burger", "pizza", "bakery", "dhaba", "sweet", "food", "kitchen", "eats", "biryani",
                "domino", "kfc", "dunzo", "blinkit", "zepto", "instamart", "bigbasket", "grocery",
                "kirana", "fruits", "vegetables", "dmart", "supermarket") -> "Food & Dining"

            has("irctc", "makemytrip", "goibibo", "cleartrip", "yatra", "indigo", "air india",
                "vistara", "akasa", "spicejet", "redbus", "abhibus", "oyo", "airbnb", "booking.com") -> "Travel"

            has("uber", "ola", "rapido", "fuel", "petrol", "diesel", "indianoil", "iocl", "hpcl",
                "bpcl", "metro", "toll", "fastag", "parking", "namma yatri") -> "Transportation"

            has("amazon", "flipkart", "myntra", "ajio", "zara", "h&m", "meesho", "nykaa", "clothing",
                "apparel", "decathlon", "croma", "reliance digital", "ikea", "mart") -> "Shopping"

            has("airtel", "jio", "vodafone", "bsnl", "bescom", "electricity", "broadband", "wifi",
                "gas", "cylinder", "water", "bill", "recharge", "dth", "tata play", "insurance",
                "lic", "rent", "emi") -> "Bills & Utilities"

            has("pharmacy", "medical", "hospital", "clinic", "apollo", "1mg", "medplus", "doctor",
                "diagnostic", "pharmeasy", "netmeds", "practo") -> "Health & Medical"

            has("netflix", "spotify", "prime video", "hotstar", "cinema", "pvr", "inox",
                "bookmyshow", "youtube", "jiocinema", "sonyliv", "zee5", "steam", "playstation") -> "Entertainment"

            else -> "General"
        }
    }

    // ---------------------------------------------------------------- prompt notification

    fun show(context: Context, txn: DetectedTxn) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create high importance notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                UpiPrompt.CHANNEL_ID,
                UpiPrompt.CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = UpiPrompt.CHANNEL_DESC
                enableLights(true)
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }

        // Auto-confirm: no response within the configured minutes (or a swipe away) logs it
        val autoMinutes = UpiAutoConfirm.getDelayMinutes(context)
        val autoConfirm = autoMinutes > 0

        // Action 1: "Yes" (Broadcast to UpiActionReceiver)
        val yesIntent = Intent(context, UpiActionReceiver::class.java).apply {
            action = UpiPrompt.ACTION_UPI_YES
            putExtra("amount", txn.amount)
            putExtra("merchant", txn.merchant)
            putExtra("category", txn.category)
            putExtra("timestamp", txn.timestamp)
            putExtra("sourcePackage", txn.sourcePackage)
            putExtra("notificationId", txn.notificationId)
            putExtra("autoConfirm", autoConfirm)
            putExtra("note", txn.note)
        }
        val yesPendingIntent = PendingIntent.getBroadcast(
            context,
            txn.notificationId * 10 + 1,
            yesIntent,
            immutableFlags()
        )

        // Action 2: "No" (Dismiss)
        val noIntent = Intent(context, UpiActionReceiver::class.java).apply {
            action = UpiPrompt.ACTION_UPI_NO
            putExtra("notificationId", txn.notificationId)
        }
        val noPendingIntent = PendingIntent.getBroadcast(
            context,
            txn.notificationId * 10 + 2,
            noIntent,
            immutableFlags()
        )

        // Action 3: "Edit" (Launch MainActivity into AddExpenseScreen with prefilled values)
        val editUri = Uri.parse(
            "expensetracker://upiEdit?amount=${txn.amount}&title=${Uri.encode(txn.merchant)}" +
                "&category=${Uri.encode(txn.category)}&notificationId=${txn.notificationId}" +
                "&timestamp=${txn.timestamp}" +
                (txn.note?.let { "&note=${Uri.encode(it)}" } ?: "")
        )
        val editIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = editUri
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val editPendingIntent = PendingIntent.getActivity(
            context,
            txn.notificationId * 10 + 3,
            editIntent,
            immutableFlags()
        )

        val formattedAmount = UpiAutoConfirm.formatAmount(txn.amount)
        val sourceLine = txn.sourceLabel?.let { "$it\n" } ?: ""

        val autoLabel = if (autoMinutes == 1L) "1 min" else "$autoMinutes min"
        val contentText = if (autoConfirm) {
            "Suggested: ${txn.category} • Auto-adds in $autoLabel if no response"
        } else {
            "Suggested: ${txn.category} • Tap 'Yes' to log or 'Edit' to customize"
        }
        val bigText = if (autoConfirm) {
            "${sourceLine}Paid $formattedAmount to ${txn.merchant}\nSuggested Category: ${txn.category}\n\n" +
                "Log this expense to your active book?\nAuto-adds in $autoLabel if you don't respond. Swiping away also adds it."
        } else {
            "${sourceLine}Paid $formattedAmount to ${txn.merchant}\nSuggested Category: ${txn.category}\n\nLog this expense to your active book?"
        }

        val builder = NotificationCompat.Builder(context, UpiPrompt.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Detected payment: $formattedAmount to ${txn.merchant}")
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // No content intent: tapping the card does nothing; only ✏️ Edit opens the editor
            .addAction(android.R.drawable.checkbox_on_background, "✓ Yes", yesPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "✕ No", noPendingIntent)
            .addAction(android.R.drawable.ic_menu_edit, "✏️ Edit", editPendingIntent)
        if (txn.sourceLabel != null) builder.setSubText(txn.sourceLabel)

        if (autoConfirm) {
            val dueAt = System.currentTimeMillis() + autoMinutes * 60_000L
            // Save pending record before posting so an instant tap can always claim it
            UpiAutoConfirm.savePending(
                context,
                txn.notificationId,
                txn.amount,
                txn.merchant,
                txn.category,
                txn.timestamp,
                txn.sourcePackage,
                dueAt,
                txn.note
            )
            builder.setDeleteIntent(UpiAutoConfirm.dismissPendingIntent(context, txn.notificationId))
            UpiAutoConfirm.scheduleAlarm(context, txn.notificationId, dueAt)
        }

        nm.notify(txn.notificationId, builder.build())
    }

    private fun immutableFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
}
