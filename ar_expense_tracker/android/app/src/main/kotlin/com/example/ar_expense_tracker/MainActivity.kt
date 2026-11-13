package com.example.ar_expense_tracker

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.example.ar_expense_tracker/upi_tracking"
        private const val REQUEST_SMS_PERMISSION = 4721
        private var activeMethodChannel: MethodChannel? = null

        fun dispatchUpiExpenseApproved(txnJson: String) {
            activeMethodChannel?.invokeMethod("onUpiExpenseApproved", txnJson)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        activeMethodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingUpiExpenses" -> {
                    // Commit overdue auto-confirm prompts first (alarm delayed by Doze / lost on reboot)
                    try {
                        UpiAutoConfirm.reconcile(context, dispatchLive = false)
                    } catch (_: Exception) {}
                    // Prompt for bank debit SMS the live receiver missed (e.g. autostart blocked)
                    try {
                        BankSmsTracker.catchUp(context)
                    } catch (_: Exception) {}
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val queue = prefs.getString("flutter.pending_upi_approved_queue", "[]") ?: "[]"
                    // Clear queue once read
                    prefs.edit().putString("flutter.pending_upi_approved_queue", "[]").apply()
                    result.success(queue)
                }
                "isSmsPermissionGranted" -> {
                    result.success(BankSmsTracker.hasReceivePermission(context) && BankSmsTracker.hasReadPermission(context))
                }
                "requestSmsPermission" -> {
                    if (BankSmsTracker.hasReceivePermission(context) && BankSmsTracker.hasReadPermission(context)) {
                        BankSmsTracker.markScanStart(context)
                        result.success(true)
                    } else {
                        pendingSmsPermissionResult?.success(false)
                        pendingSmsPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                            REQUEST_SMS_PERMISSION
                        )
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private var pendingSmsPermissionResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_SMS_PERMISSION) return
        val granted = BankSmsTracker.hasReceivePermission(this) && BankSmsTracker.hasReadPermission(this)
        if (granted) BankSmsTracker.markScanStart(this)
        pendingSmsPermissionResult?.success(granted)
        pendingSmsPermissionResult = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        handleUpiEditIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        handleUpiEditIntent(intent)
        super.onNewIntent(intent)
    }

    /**
     * ✏️ Edit hands the transaction to AddExpenseScreen, so drop its pending auto-confirm and the
     * prompt notification; otherwise the timeout would log a duplicate.
     */
    private fun handleUpiEditIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != "expensetracker" || !data.toString().lowercase().contains("upiedit")) return
        val notifId = data.getQueryParameter("notificationId")?.toIntOrNull() ?: return
        try {
            UpiAutoConfirm.discardPending(this, notifId)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notifId)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        if (activeMethodChannel != null) {
            activeMethodChannel = null
        }
        super.onDestroy()
    }
}
