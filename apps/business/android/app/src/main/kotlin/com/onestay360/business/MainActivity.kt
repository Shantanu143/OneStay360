package com.onestay360.business

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create notification channel for enrollment requests (Android 8.0+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val enrollmentChannel = NotificationChannel(
                "enrollment_requests",
                "Enrollment Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new enrollment requests from tenants"
                enableVibration(true)
                setShowBadge(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(enrollmentChannel)
        }
    }
}
