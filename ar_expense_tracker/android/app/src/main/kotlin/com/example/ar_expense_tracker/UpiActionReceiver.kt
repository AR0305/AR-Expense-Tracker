package com.example.ar_expense_tracker

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class UpiActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = intent.getIntExtra("notificationId", -1)
        if (notifId != -1) {
            nm.cancel(notifId)
        }

        when (intent.action) {
            UpiPrompt.ACTION_UPI_YES -> {
                val amount = intent.getDoubleExtra("amount", 0.0)
                val merchant = intent.getStringExtra("merchant") ?: "UPI Expense"
                val category = intent.getStringExtra("category") ?: "General"
                val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())
                val sourcePackage = intent.getStringExtra("sourcePackage") ?: ""
                val autoConfirm = intent.getBooleanExtra("autoConfirm", false)

                if (amount <= 0.0) return

                if (autoConfirm && notifId != -1) {
                    UpiAutoConfirm.cancelAlarm(context, notifId)
                    // Already logged by timeout / swipe, or discarded by Edit
                    UpiAutoConfirm.takePending(context, notifId) ?: return
                }

                // Queue for Flutter + dispatch to live engine if running
                UpiAutoConfirm.enqueueApproved(
                    context, amount, merchant, category, timestamp, sourcePackage,
                    note = intent.getStringExtra("note")
                )

                showAddedToast(context, amount, merchant)
            }

            UpiPrompt.ACTION_UPI_NO -> {
                // Dismissed silently; drop any pending auto-confirm
                if (notifId != -1) UpiAutoConfirm.discardPending(context, notifId)
            }

            UpiAutoConfirm.ACTION_UPI_AUTO_CONFIRM -> {
                if (notifId == -1) return
                val pending = UpiAutoConfirm.takePending(context, notifId) ?: return
                UpiAutoConfirm.enqueueFromPending(context, pending)
                UpiAutoConfirm.showAutoAddedNotification(context, notifId, pending)
            }

            UpiAutoConfirm.ACTION_UPI_DISMISSED -> {
                // Swipe away / clear-all = save
                if (notifId == -1) return
                UpiAutoConfirm.cancelAlarm(context, notifId)
                val pending = UpiAutoConfirm.takePending(context, notifId) ?: return
                UpiAutoConfirm.enqueueFromPending(context, pending)
                showAddedToast(
                    context,
                    pending.optDouble("amount", 0.0),
                    pending.optString("merchant", "UPI Expense")
                )
            }
        }
    }

    private fun showAddedToast(context: Context, amount: Double, merchant: String) {
        Toast.makeText(
            context,
            "${UpiAutoConfirm.formatAmount(amount)} to $merchant added!",
            Toast.LENGTH_SHORT
        ).show()
    }
}
