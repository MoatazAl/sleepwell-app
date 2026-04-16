package com.example.sleep_app

import android.app.Activity
import android.content.Context
import com.samsung.android.sdk.health.data.HealthDataService
import com.samsung.android.sdk.health.data.HealthDataStore
import com.samsung.android.sdk.health.data.error.HealthDataException
import com.samsung.android.sdk.health.data.error.ResolvablePlatformException
import com.samsung.android.sdk.health.data.permission.AccessType
import com.samsung.android.sdk.health.data.permission.Permission
import com.samsung.android.sdk.health.data.request.DataType
import com.samsung.android.sdk.health.data.request.DataTypes
import com.samsung.android.sdk.health.data.request.LocalTimeFilter
import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime

class SamsungHealthManager(private val context: Context) {

    private val store: HealthDataStore by lazy {
        HealthDataService.getStore(context)
    }

    private fun requiredPermissions(): Set<Permission> {
        return setOf(
            Permission.of(DataTypes.SLEEP, AccessType.READ)
        )
    }

    suspend fun hasSleepReadPermission(): Boolean {
        val required = requiredPermissions()
        val granted = store.getGrantedPermissions(required)
        return granted.containsAll(required)
    }

    suspend fun requestSleepReadPermission(activity: Activity): Boolean {
        val required = requiredPermissions()
        val granted = store.getGrantedPermissions(required)

        if (granted.containsAll(required)) {
            return true
        }

        val requestResult = store.requestPermissions(required, activity)
        return requestResult.containsAll(required)
    }

    suspend fun readLatestSleep(): Map<String, Any?>? {
        try {
            val end = LocalDateTime.now()
            val start = end.minusHours(36)

            val request = DataTypes.SLEEP.readDataRequestBuilder
                .setLocalTimeFilter(LocalTimeFilter.of(start, end))
                .build()

            val response = store.readDataAsync(request).get()
            val dataList = response.dataList

            if (dataList.isEmpty()) {
                return null
            }

            val latest = dataList.maxByOrNull { it.endTime ?: Instant.EPOCH } ?: return null

            val duration = latest.getValue(DataType.SleepType.DURATION) ?: Duration.ZERO
            val score = latest.getValue(DataType.SleepType.SLEEP_SCORE)
            val sessions = latest.getValue(DataType.SleepType.SESSIONS) ?: emptyList()

            val stageMaps = mutableListOf<Map<String, Any?>>()

            sessions.forEach { session ->
                val stages = session.stages ?: emptyList()
                stages.forEach { stage ->
                    stageMaps.add(
                        mapOf(
                            "stage" to stageTypeToLabel(stage.stage),
                            "start" to stage.startTime.toString(),
                            "end" to stage.endTime.toString()
                        )
                    )
                }
            }

            return mapOf(
                "start" to latest.startTime.toString(),
                "end" to latest.endTime.toString(),
                "durationHours" to duration.toMinutes() / 60.0,
                "durationMinutes" to duration.toMinutes(),
                "sleepScore" to score,
                "stages" to stageMaps,
                "source" to "samsung_health"
            )
        } catch (e: ResolvablePlatformException) {
            if (e.hasResolution) {
                throw Exception("Samsung Health needs user action before data can be read.")
            }
            throw e
        } catch (e: HealthDataException) {
            throw Exception("Samsung Health read failed: ${e.message}")
        }
    }

    private fun stageTypeToLabel(stage: Any?): String {
        val value = stage?.toString()?.lowercase() ?: return "unknown"

        return when {
            value.contains("awake") -> "awake"
            value.contains("light") -> "light"
            value.contains("deep") -> "deep"
            value.contains("rem") -> "rem"
            else -> "unknown"
        }
    }
}