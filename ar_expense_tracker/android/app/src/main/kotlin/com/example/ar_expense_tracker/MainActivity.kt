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
                    // Not cleared here: Flutter calls ackUpiExpenses once each transaction is saved
                    result.success(UpiAutoConfirm.readApprovedQueue(context))
                }
                "ackUpiExpenses" -> {
                    val ids = (call.arguments as? List<*>)?.filterIsInstance<String>().orEmpty()
                    if (ids.isNotEmpty()) UpiAutoConfirm.removeFromApprovedQueue(context, ids.toSet())
                    result.success(true)
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
                "getBackgroundAccess" -> {
                    result.success(
                        mapOf(
                            "batteryUnrestricted" to BackgroundAccess.isIgnoringBatteryOptimizations(context),
                            "hasAutostartSetting" to BackgroundAccess.hasAutostartSetting(),
                            "manufacturer" to BackgroundAccess.manufacturer()
                        )
                    )
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(BackgroundAccess.requestIgnoreBatteryOptimizations(this))
                }
                "openAutostartSettings" -> {
                    result.success(BackgroundAccess.openAutostartSettings(this))
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
     *
     * If the timeout (or a swipe) already logged it just before the tap, add `alreadyAdded=1` to the
     * link so Flutter tells the user instead of opening an editor that would save it twice.
     */
    private fun handleUpiEditIntent(intent: Intent?) {
        if (intent == null) return
        val data = intent.data ?: return
        if (data.scheme != "expensetracker" || !data.toString().lowercase().contains("upiedit")) return
        val notifId = data.getQueryParameter("notificationId")?.toIntOrNull() ?: return
        try {
            UpiAutoConfirm.discardPending(this, notifId)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notifId)
            if (UpiAutoConfirm.wasAutoAdded(this, notifId) && data.getQueryParameter("alreadyAdded") == null) {
                intent.data = data.buildUpon().appendQueryParameter("alreadyAdded", "1").build()
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        if (activeMethodChannel != null) {
            activeMethodChannel = null
        }
        super.onDestroy()
    }
}
