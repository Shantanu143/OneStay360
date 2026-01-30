# Push Notifications Setup Checklist

Complete these steps to enable push notifications for enrollment requests:

## ✅ Backend Setup (Cloud Functions)

- [x] Created `functions/enrollmentNotifications.ts` with:
  - [x] `onEnrollmentRequestCreated()` - Sends notification on enrollment request
  - [x] `registerDeviceToken()` - Callable function to register device tokens
  - [x] `cleanupInactiveDeviceTokens()` - Scheduled cleanup (daily)
- [x] Updated `functions/index.ts` to export new functions
- [x] Ready to deploy: `firebase deploy --only functions`

---

## ✅ Business App Setup (Flutter)

### Dependencies
- [x] Added `firebase_messaging: ^15.2.10` to pubspec.yaml
- [x] Ran `flutter pub get`

### Code Changes
- [x] Created `lib/services/device_token_service.dart`
  - Handles FCM initialization
  - Registers device tokens
  - Processes notifications
- [x] Updated `lib/main.dart`
  - Added background message handler
  - Initialize DeviceTokenService on app startup
  - Import firebase_messaging

### Android Configuration
- [ ] **TODO**: Update `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <!-- Add permission -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  
  <!-- Add notification channel metadata -->
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="enrollment_requests" />
  ```

- [ ] **TODO**: Update `android/app/src/main/kotlin/MainActivity.kt` (or Java):
  ```kotlin
  override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      
      // Create notification channel for enrollment requests
      val channel = NotificationChannel(
          "enrollment_requests",
          "Enrollment Requests",
          NotificationManager.IMPORTANCE_HIGH
      )
      val manager = getSystemService(NotificationManager::class.java)
      manager?.createNotificationChannel(channel)
  }
  ```

### iOS Configuration
- [ ] **TODO**: Request notification permissions in Info.plist or code
- [ ] **TODO**: Test on physical iOS device (simulators may not receive FCM)

---

## ✅ Tenant App Setup (Flutter)

- [x] Added `firebase_messaging: ^15.2.10` to pubspec.yaml
- [x] Ran `flutter pub get`

> **Note**: Tenant app doesn't need device token registration since it's not receiving these notifications. Dependencies added for future use if tenant notifications are needed.

---

## ⚠️ Firestore Rules Update

Ensure your Firestore rules allow device token storage:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to manage their own device tokens
    match /users/{userId}/deviceTokens/{tokenId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

---

## ⚠️ Firestore Data Requirements

Verify these collections exist and have proper data:

### 1. `/businesses/{businessId}`
Must have `ownerUserId` field:
```
{
  "name": "Property Name",
  "ownerUserId": "user-uid-here",  // REQUIRED for notifications
  "city": "...",
  "...": "..."
}
```

### 2. `/enrollmentRequests/{requestId}`
Should have (auto-populated by function):
```
{
  "tenantId": "...",
  "propertyId": "...",
  "tenantName": "...",
  "moveInDate": Timestamp,
  "notificationsSentAt": Timestamp,  // Added by function
  "notificationsSentTo": 2,          // Added by function
  "...": "..."
}
```

---

## 🚀 Testing Checklist

### Before Testing
- [ ] Deployed Cloud Functions: `firebase deploy --only functions`
- [ ] Updated Android manifest & MainActivity
- [ ] Business app compiled and running on device/emulator
- [ ] Business owner logged in to app
- [ ] Notifications granted permission (iOS)
- [ ] Device token visible in Firestore: `/users/{userId}/deviceTokens/`

### Test Enrollment Request Notification
1. [ ] Open tenant app
2. [ ] Navigate to a property
3. [ ] Tap "Send Request"
4. [ ] Fill in enrollment form
5. [ ] Submit request
6. [ ] Check business app:
   - [ ] Receives notification (foreground or background)
   - [ ] Notification shows property name and tenant name
   - [ ] Can tap notification to see details

### Monitor Logs
- [ ] Check Cloud Functions logs:
  ```bash
  firebase functions:log --follow
  ```
- [ ] Look for messages starting with ✅ or ❌
- [ ] Verify all notifications "sent" counter matches

### Firestore Verification
- [ ] Check `/enrollmentRequests/{requestId}`:
  ```
  notificationsSentAt: (timestamp)
  notificationsSentTo: 1+
  notificationsFailed: 0
  ```

---

## 📱 Device Token Management

### View Registered Device Tokens
```
Firestore → users → {userId} → deviceTokens
```

Each device shows:
```
{
  "token": "firebase-messaging-token",
  "active": true,
  "registeredAt": Timestamp,
  "lastSeenAt": Timestamp,
  "deviceName": "Business iPhone",
  "deviceModel": "iOS 15.0"
}
```

### Manual Token Cleanup
Inactive tokens are auto-cleaned daily. To manually cleanup:

Firestore query:
```
collection("users/{userId}/deviceTokens")
  .where("active", "==", false)
  .delete()
```

---

## 🔧 Troubleshooting

### Notifications Not Received

**Step 1**: Verify device token is registered
```
Firestore → users/{userId}/deviceTokens → (should have entries)
```

**Step 2**: Check business owner ID is set
```
Firestore → businesses/{businessId} → ownerUserId (must exist)
```

**Step 3**: Check Cloud Function logs
```bash
firebase functions:log
# Look for errors in onEnrollmentRequestCreated
```

**Step 4**: Verify Android manifest has:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Step 5**: Check notification channel created
```kotlin
NotificationChannel("enrollment_requests", "Enrollment Requests", ...)
```

**Step 6**: Test with Firebase Console
- Go to Cloud Messaging
- Send manual test notification to your device
- If that works, issue is with function logic

### Token Not Registering

**Causes**:
- User not authenticated when app initializes
- DeviceTokenService.initialize() not called
- Firestore rules blocking token writes

**Solution**:
```dart
// Check logs for timing issues
// Increase delay if needed:
await Future.delayed(const Duration(seconds: 1));
await DeviceTokenService().initialize();
```

---

## 📊 Monitoring

### Cloud Functions Dashboard
```
Firebase Console → Functions → enrollmentNotifications
```

Monitor:
- Execution count (should spike when requests submitted)
- Error rate (should be < 5%)
- Average duration (should be < 2s)
- Recent logs

### Firestore Metrics
Track enrollment requests with notifications:
```firestore
SELECT COUNT(*) FROM enrollmentRequests 
WHERE notificationsSentAt != null
AND timestamp >= 7 DAYS_AGO
```

---

## 📝 Next Steps

1. **Deploy Functions**:
   ```bash
   cd functions
   npm install  # if needed
   firebase deploy --only functions
   ```

2. **Update Android Manifest** (see section above)

3. **Build & Run Business App**:
   ```bash
   cd apps/business
   flutter pub get
   flutter run
   ```

4. **Test End-to-End**:
   - Tenant submits enrollment request
   - Business owner receives notification
   - Tap notification to view request details

5. **Monitor First Week**:
   - Check logs for errors
   - Verify all notifications delivered
   - Adjust error handling if needed

---

## 🎯 Feature Completion

- [x] Cloud Function triggers on enrollment request
- [x] Device token registration service
- [x] Notification sent to business owner
- [x] Token cleanup scheduled
- [x] Error handling for invalid tokens
- [ ] Android manifest updates (TODO)
- [ ] iOS configuration (TODO)
- [ ] Unit tests (TODO)
- [ ] Analytics tracking (TODO)

---

## 📚 Documentation Files

- `PUSH_NOTIFICATIONS_GUIDE.md` - Comprehensive system documentation
- `ENROLLMENT_FLOW_OPTION2.md` - Simplified enrollment dialog
- This file - Quick setup checklist
