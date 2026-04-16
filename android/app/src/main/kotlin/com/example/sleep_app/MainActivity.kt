package com.example.sleep_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.contracts.HealthPermissionsRequestContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val HC_CHANNEL = "sleepwell/health_connect"
        private const val SH_CHANNEL = "sleepwell/samsung_health"
    }

    private lateinit var healthConnectManager: HealthConnectManager
    private lateinit var samsungHealthManager: SamsungHealthManager

    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var pendingHealthConnectPermissionResult: MethodChannel.Result? = null

    private val requestPermissions =
        registerForActivityResult(HealthPermissionsRequestContract()) { granted: Set<String> ->
            val result = pendingHealthConnectPermissionResult
            pendingHealthConnectPermissionResult = null
            result?.success(
                mapOf(
                    "granted" to granted.contains(healthConnectManager.sleepReadPermission()),
                    "permissions" to granted.toList()
                )
            )
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        healthConnectManager = HealthConnectManager(this)
        samsungHealthManager = SamsungHealthManager(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HC_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAvailability" -> {
                    val status = healthConnectManager.sdkStatus()
                    result.success(
                        mapOf(
                            "status" to status,
                            "available" to (status == HealthConnectClient.SDK_AVAILABLE)
                        )
                    )
                }

                "openHealthConnectSettings" -> {
                    openHealthConnectSettings()
                    result.success(true)
                }

                "hasSleepPermission" -> {
                    activityScope.launch {
                        try {
                            result.success(healthConnectManager.hasSleepReadPermission())
                        } catch (e: Exception) {
                            result.error("PERMISSION_CHECK_FAILED", e.message, null)
                        }
                    }
                }

                "requestSleepPermission" -> {
                    try {
                        pendingHealthConnectPermissionResult = result
                        requestPermissions.launch(setOf(healthConnectManager.sleepReadPermission()))
                    } catch (e: Exception) {
                        pendingHealthConnectPermissionResult = null
                        result.error("PERMISSION_REQUEST_FAILED", e.message, null)
                    }
                }

                "readLatestSleepSession" -> {
                    activityScope.launch {
                        try {
                            result.success(healthConnectManager.readLatestSleepSession())
                        } catch (e: Exception) {
                            result.error("READ_SLEEP_FAILED", e.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SH_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSleepPermission" -> {
                    activityScope.launch {
                        try {
                            result.success(samsungHealthManager.hasSleepReadPermission())
                        } catch (e: Exception) {
                            result.error("SAMSUNG_PERMISSION_CHECK_FAILED", e.message, null)
                        }
                    }
                }

                "requestSleepPermission" -> {
                    activityScope.launch {
                        try {
                            val granted = samsungHealthManager.requestSleepReadPermission(this@MainActivity)
                            result.success(
                                mapOf(
                                    "granted" to granted,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("SAMSUNG_PERMISSION_REQUEST_FAILED", e.message, null)
                        }
                    }
                }

                "readLatestSleep" -> {
                    activityScope.launch {
                        try {
                            result.success(samsungHealthManager.readLatestSleep())
                        } catch (e: Exception) {
                            result.error("SAMSUNG_READ_SLEEP_FAILED", e.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openHealthConnectSettings() {
        val uri = Uri.parse("market://details?id=${HealthConnectManager.HEALTH_CONNECT_PACKAGE}")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        startActivity(intent)
    }
}