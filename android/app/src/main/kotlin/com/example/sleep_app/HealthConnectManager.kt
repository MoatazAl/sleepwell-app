package com.example.sleep_app

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.temporal.ChronoUnit

class HealthConnectManager(private val context: Context) {

    companion object {
        const val HEALTH_CONNECT_PACKAGE = "com.google.android.apps.healthdata"
    }

    private val client by lazy {
        HealthConnectClient.getOrCreate(context)
    }

    fun sdkStatus(): Int {
        return HealthConnectClient.getSdkStatus(context, HEALTH_CONNECT_PACKAGE)
    }

    fun sleepReadPermission(): String {
        return HealthPermission.getReadPermission(SleepSessionRecord::class)
    }

    suspend fun hasSleepReadPermission(): Boolean {
        val granted = client.permissionController.getGrantedPermissions()
        return granted.contains(sleepReadPermission())
    }

    suspend fun readLatestSleepSession(): Map<String, Any?>? = withContext(Dispatchers.IO) {
        val end = Instant.now()
        val start = end.minus(36, ChronoUnit.HOURS)

        val response = client.readRecords(
            ReadRecordsRequest(
                recordType = SleepSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end),
                ascendingOrder = false,
                pageSize = 20
            )
        )

        val records = response.records
            .filter { it.endTime.isBefore(Instant.now().plusSeconds(60)) }
            .sortedByDescending { it.endTime }

        val latest = records.firstOrNull() ?: return@withContext null

        val durationMinutes = ChronoUnit.MINUTES.between(latest.startTime, latest.endTime)
        val durationHours = durationMinutes / 60.0

        val stages = latest.stages.map { stage ->
            mapOf(
                "stage" to stageTypeToLabel(stage.stage),
                "stageCode" to stage.stage,
                "start" to stage.startTime.toString(),
                "end" to stage.endTime.toString()
            )
        }

        mapOf(
            "start" to latest.startTime.toString(),
            "end" to latest.endTime.toString(),
            "title" to latest.title,
            "notes" to latest.notes,
            "sourcePackage" to latest.metadata.dataOrigin.packageName,
            "durationHours" to durationHours,
            "durationMinutes" to durationMinutes,
            "stages" to stages
        )
    }

    private fun stageTypeToLabel(stage: Int): String {
        return when (stage) {
            SleepSessionRecord.STAGE_TYPE_UNKNOWN -> "unknown"
            SleepSessionRecord.STAGE_TYPE_AWAKE -> "awake"
            SleepSessionRecord.STAGE_TYPE_SLEEPING -> "sleeping"
            SleepSessionRecord.STAGE_TYPE_OUT_OF_BED -> "out_of_bed"
            SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED -> "awake_in_bed"
            SleepSessionRecord.STAGE_TYPE_LIGHT -> "light"
            SleepSessionRecord.STAGE_TYPE_DEEP -> "deep"
            SleepSessionRecord.STAGE_TYPE_REM -> "rem"
            else -> "unknown"
        }
    }
}