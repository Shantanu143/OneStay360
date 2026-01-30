package com.onestay360.tenant

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create notification channels (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Channel for enrollment request responses
            val enrollmentChannel = NotificationChannel(
                "enrollment_requests",
                "Enrollment Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications about your enrollment requests"
                enableVibration(true)
                setShowBadge(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(enrollmentChannel)
        }
    }
}
