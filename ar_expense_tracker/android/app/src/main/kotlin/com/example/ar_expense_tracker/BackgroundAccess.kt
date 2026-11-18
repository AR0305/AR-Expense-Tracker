package com.example.ar_expense_tracker

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import java.util.Locale

/**
 * Background access for bank SMS tracking.
 *
 * The live [BankSmsReceiver] only runs while the app is closed if the phone lets it. Stock Android
 * allows it, but many OEM builds (Xiaomi / HyperOS / MIUI, Oppo / Realme / ColorOS, Vivo / iQOO,
 * Huawei / Honor, OnePlus, Asus) block broadcasts to apps that lack "Autostart" or are battery
 * restricted. Then prompts (and their auto-confirm timers) only appear when the app is opened and
 * [BankSmsTracker.catchUp] runs. Apps cannot switch these on themselves; this opens the screens.
 */
object BackgroundAccess {
    private const val TAG = "BackgroundAccess"

    /** Manufacturers whose builds have an Autostart / background-launch switch. */
    private val AUTOSTART_BRANDS = setOf(
        "xiaomi", "redmi", "poco", "oppo", "realme", "oneplus", "vivo", "iqoo",
        "huawei", "honor", "asus", "letv", "meizu"
    )

    /** Known Autostart screens, tried in order. Unexported or missing ones are skipped. */
    private val AUTOSTART_COMPONENTS = listOf(
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oplus.safecenter" to "com.oplus.safecenter.permission.startup.StartupAppListActivity",
        "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
        "com.asus.mobilemanager" to "com.asus.mobilemanager.MainActivity",
        "com.letv.android.letvsafe" to "com.letv.android.letvsafe.AutobootManageActivity",
        "com.meizu.safe" to "com.meizu.safe.permission.SmartBGActivity"
    )

    fun manufacturer(): String = Build.MANUFACTURER.orEmpty()

    fun hasAutostartSetting(): Boolean {
        val brand = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase(Locale.ROOT)
        return AUTOSTART_BRANDS.any { brand.contains(it) }
    }

    /** True when Android's battery optimization does not restrict this app. */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Shows the system "Allow app to always run in background?" dialog, falling back to the
     * battery optimization list, then to the app's settings page.
     */
    @SuppressLint("BatteryLife")
    fun requestIgnoreBatteryOptimizations(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:${activity.packageName}"))
        return tryStart(activity, direct) ||
            tryStart(activity, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            openAppDetails(activity)
    }

    /** Opens the OEM Autostart screen, or the app's settings page if none is found. */
    fun openAutostartSettings(activity: Activity): Boolean {
        for ((pkg, cls) in AUTOSTART_COMPONENTS) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
            if (tryStart(activity, intent)) return true
        }
        return openAppDetails(activity)
    }

    private fun openAppDetails(activity: Activity): Boolean = tryStart(
        activity,
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", activity.packageName, null))
    )

    private fun tryStart(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (e: Exception) {
        // ActivityNotFoundException (screen missing) or SecurityException (not exported)
        Log.d(TAG, "Cannot open ${intent.component ?: intent.action}: ${e.javaClass.simpleName}")
        false
    }
}
