package app.tithi.pro

import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannelName = "app.tithi.pro/app_update"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super so the window is already laid out edge-to-edge for the
        // very first frame, including the launch-theme window.
        applyEdgeToEdge()
        super.onCreate(savedInstanceState)
        applyLaunchSystemBarIcons()
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter's non-edge-to-edge fallback restores the decor-view flags on
        // every resume. `SystemUiMode.edgeToEdge` (requested from Dart in
        // AppBootstrap) makes the engine re-apply the modern API itself from
        // API 29 up, but below that the mode is unsupported, so keep the
        // window behind the navigation bar here.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            applyEdgeToEdge()
        }
    }

    /**
     * Edge-to-edge opt-in equivalent to `androidx.activity.enableEdgeToEdge()`.
     *
     * `FlutterActivity` extends `android.app.Activity`, not
     * `ComponentActivity`, so the ActivityX extension cannot be called. Both
     * system bars are transparent and, from API 29, their automatic contrast
     * scrim is disabled: the app's background paints through the gesture and
     * 3-button navigation area instead of showing a bar behind it.
     */
    private fun applyEdgeToEdge() {
        // Below API 30 this only adds the LAYOUT_* flags; it leaves the
        // SYSTEM_UI_FLAG_LIGHT_* bits alone, so the bar icon colours Dart set
        // through SystemChrome survive a re-apply on resume.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = Color.TRANSPARENT
        // Dark navigation icons (`SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR`) only
        // exist from API 26, so a transparent bar would hide the buttons over
        // light content below that. Older devices keep the platform bar.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.navigationBarColor = Color.TRANSPARENT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }

    /**
     * Match the system bar icons to the launch theme before Flutter's first
     * frame. Dart re-applies the effective app theme in `AppBootstrap`.
     */
    private fun applyLaunchSystemBarIcons() {
        val nightMode = resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK
        val lightIcons = nightMode == Configuration.UI_MODE_NIGHT_YES
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = !lightIcons
            isAppearanceLightNavigationBars = !lightIcons
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Missing APK path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    "canRequestInstalls" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }
                    "openInstallPermissionSettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) },
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_FAILED", e.message, null)
                        }
                    }
                    // Flutter adds abiIndex * 1000 to versionCode for split
                    // APKs, so PackageInfo.buildNumber is not the +N that
                    // release tags carry. The manifest meta-data is filled
                    // from flutter.versionCode before that offset is applied,
                    // and stays exact even after +N passes 1000.
                    "baseBuildNumber" -> {
                        val meta = packageManager
                            .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                            .metaData
                        val base = meta?.get("baseBuildNumber")
                        if (base == null) {
                            result.error(
                                "NO_BASE_BUILD_NUMBER",
                                "baseBuildNumber meta-data is missing",
                                null,
                            )
                        } else {
                            result.success(base.toString())
                        }
                    }
                    // Release APKs are published per ABI; the Dart side picks
                    // the asset that matches this device instead of always
                    // taking the arm64 one. Preference order is the platform
                    // order, primary ABI first.
                    "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(path: String) {
        val file = File(path)
        require(file.exists()) { "Downloaded APK file not found" }
        // Android 8+: sideloading needs the per-app "install unknown apps"
        // permission. Send the user to settings instead of failing silently.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) },
            )
            throw SecurityException(
                "Allow installs from Tithi in system settings, then tap Install again.",
            )
        }
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
