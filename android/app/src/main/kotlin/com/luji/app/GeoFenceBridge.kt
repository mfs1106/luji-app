package com.luji.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONObject

/** Android system geofences are optional; the Flutter GPS check remains the fallback. */
object GeoFenceBridge {
    private const val preferences = "luji_native_geofences"

    fun available(context: Context): Boolean {
        if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED) return false
        if (Build.VERSION.SDK_INT >= 29 &&
            context.checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
            PackageManager.PERMISSION_GRANTED) return false
        return GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) ==
            ConnectionResult.SUCCESS
    }

    private fun intent(context: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(context, 7102,
            Intent(context, GeoFenceReceiver::class.java), flags)
    }

    fun register(context: Context, id: Int, lat: Double, lon: Double,
                 radius: Float, title: String, body: String,
                 callback: (Boolean, String?) -> Unit) {
        if (!available(context)) {
            callback(false, "后台定位权限或 Google Play 服务不可用")
            return
        }
        try {
            val fence = Geofence.Builder()
                .setRequestId(id.toString())
                .setCircularRegion(lat, lon, radius)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .build()
            val request = GeofencingRequest.Builder().setInitialTrigger(0)
                .addGeofence(fence).build()
            LocationServices.getGeofencingClient(context)
                .addGeofences(request, intent(context))
                .addOnSuccessListener {
                    val json = JSONObject().put("lat", lat).put("lon", lon)
                        .put("radius", radius.toDouble()).put("title", title)
                        .put("body", body)
                    context.getSharedPreferences(preferences, Context.MODE_PRIVATE)
                        .edit().putString(id.toString(), json.toString()).apply()
                    callback(true, null)
                }
                .addOnFailureListener { callback(false, it.message) }
        } catch (error: Exception) {
            callback(false, error.message)
        }
    }

    fun remove(context: Context, id: Int) {
        context.getSharedPreferences(preferences, Context.MODE_PRIVATE)
            .edit().remove(id.toString()).apply()
        try {
            LocationServices.getGeofencingClient(context)
                .removeGeofences(listOf(id.toString()))
        } catch (_: Exception) { }
    }

    fun saved(context: Context, id: String): JSONObject? {
        val value = context.getSharedPreferences(preferences, Context.MODE_PRIVATE)
            .getString(id, null) ?: return null
        return try { JSONObject(value) } catch (_: Exception) { null }
    }

    fun restore(context: Context, done: () -> Unit) {
        val all = context.getSharedPreferences(preferences, Context.MODE_PRIVATE).all
        if (all.isEmpty()) { done(); return }
        var remaining = all.size
        for (key in all.keys) {
            val id = key.toIntOrNull()
            val item = saved(context, key)
            if (id == null || item == null) {
                remaining--
                if (remaining == 0) done()
                continue
            }
            register(context, id, item.getDouble("lat"), item.getDouble("lon"),
                item.getDouble("radius").toFloat(), item.getString("title"),
                item.optString("body")) { _, _ ->
                remaining--
                if (remaining == 0) done()
            }
        }
    }
}

class GeoFenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() || event.geofenceTransition !=
            Geofence.GEOFENCE_TRANSITION_ENTER) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("luji_geofence",
                "到达地点提醒", NotificationManager.IMPORTANCE_HIGH))
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return
        for (fence in event.triggeringGeofences.orEmpty()) {
            val id = fence.requestId.toIntOrNull() ?: continue
            val item = GeoFenceBridge.saved(context, fence.requestId) ?: continue
            val notification = NotificationCompat.Builder(context, "luji_geofence")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(item.optString("title", "已到达地点"))
                .setContentText(item.optString("body"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .build()
            manager.notify(id + 1000000, notification)
        }
    }
}

class GeoBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pending = goAsync()
        GeoFenceBridge.restore(context) { pending.finish() }
    }
}
