# Push Notification System for Enrollment Requests

## Overview

When a tenant submits an enrollment request, the business owner (property manager) receives a **real-time push notification** on all registered devices.

---

## Architecture

### Flow

```
Tenant App
    ↓
Submits Enrollment Request to Firestore
    ↓
/enrollmentRequests/{requestId} document created
    ↓
Cloud Function: onEnrollmentRequestCreated triggers
    ↓
Extracts property ID → identifies business owner
    ↓
Queries business owner's device tokens from /users/{userId}/deviceTokens
    ↓
Sends push notification to all active devices
    ↓
Business App receives notification
    ↓
Shows notification in UI (foreground) or system notification (background)
```

---

## Component Details

### 1. Cloud Function: `onEnrollmentRequestCreated`

**File**: `functions/enrollmentNotifications.ts`

**Trigger**: Firestore write to `/enrollmentRequests/{requestId}`

**Actions**:
- Extracts business ID from property ID (BUS0000001PNR001 → BUS0000001)
- Fetches property details for display
- Gets business owner's user ID from `/businesses/{businessId}`
- Fetches all active device tokens from `/users/{ownerUserId}/deviceTokens`
- Sends FCM notifications to all tokens
- Handles invalid/expired tokens automatically
- Logs notification delivery status back to enrollment request

**Notification Payload**:
```
{
  "title": "New Enrollment Request",
  "body": "${tenantName} is interested in ${propertyName}",
  "data": {
    "requestId": "req-123",
    "propertyId": "BUS0000001PNR001",
    "businessId": "BUS0000001",
    "tenantName": "John Doe",
    "tenantPhone": "+91-9876543210",
    "moveInDate": "25/01/2026",
    "type": "enrollment_request"
  }
}
```

### 2. Cloud Function: `registerDeviceToken`

**File**: `functions/enrollmentNotifications.ts`

**Type**: Callable HTTP function

**When Called**: 
- Business app on startup (after auth initialization)
- When user logs in
- When new device registers

**Request Body**:
```dart
{
  "deviceToken": "firebase-cloud-messaging-token",
  "deviceName": "iPhone 12 Pro",     // optional
  "deviceModel": "iOS 15.0"          // optional
}
```

**Stores to**: `/users/{userId}/deviceTokens/{deviceToken}`

### 3. Cloud Function: `cleanupInactiveDeviceTokens`

**File**: `functions/enrollmentNotifications.ts`

**Type**: Scheduled function (daily @ 2:00 AM IST)

**Purpose**: Remove device tokens inactive for >30 days

---

## Business App Setup

### 1. Add firebase_messaging Dependency

**File**: `apps/business/pubspec.yaml`

```yaml
firebase_messaging: ^14.9.4
```

### 2. Create DeviceTokenService

**File**: `apps/business/lib/services/device_token_service.dart`

**Features**:
- Request notification permissions (iOS)
- Register initial device token
- Listen for token refresh
- Handle foreground messages
- Handle background messages
- Store tokens in Firestore

### 3. Update main.dart

**Changes**:
```dart
// Add at top-level
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set background handler before Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await Firebase.initializeApp(/*...*/);
  // ...
}

// In _MyAppShellState.initState():
@override
void initState() {
  super.initState();
  _setupAppLinks();
  _initializeDeviceTokenService();  // ADD THIS
}

Future<void> _initializeDeviceTokenService() async {
  try {
    await Future.delayed(const Duration(milliseconds: 500));
    await DeviceTokenService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize device token service: $e');
  }
}
```

### 4. Configure Android Notification Channel

**File**: `apps/business/android/app/src/main/AndroidManifest.xml`

Add notification channel meta-data:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="enrollment_requests" />
```

**File**: `apps/business/android/app/src/main/kotlin/MainActivity.kt` (or Java equivalent)

Add notification channel creation:
```kotlin
// In onCreate() or similar
val channel = NotificationChannel(
    "enrollment_requests",
    "Enrollment Requests",
    NotificationManager.IMPORTANCE_HIGH
)
val manager = getSystemService(NotificationManager::class.java)
manager?.createNotificationChannel(channel)
```

### 5. Update AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

---

## Firestore Data Structure

### Device Tokens Collection

**Path**: `/users/{userId}/deviceTokens/{deviceToken}`

```dart
{
  "token": "abc123xyz...firebase-token",
  "active": true,
  "registeredAt": Timestamp,
  "lastSeenAt": Timestamp,
  "deviceName": "Business iPhone",
  "deviceModel": "iOS 15.0",
  "deactivatedAt": null  // set on logout
}
```

### Enrollment Request Updates

**Path**: `/enrollmentRequests/{requestId}`

After notification send, these fields are added:
```dart
{
  // ... existing fields ...
  "notificationsSentAt": Timestamp,
  "notificationsSentTo": 2,
  "notificationsFailed": 0,
  "lastUpdated": Timestamp
}
```

---

## Notification Types & Handling

### Current: Enrollment Request

**Type**: `enrollment_request`

**Data Fields**:
- `requestId` - Link to specific request
- `propertyId` - Which property
- `businessId` - Which business
- `tenantName` - Who is requesting
- `tenantPhone` - Contact info
- `moveInDate` - When they want to move in

**Foreground Handling**: Show in-app notification or snackbar

**Background Handling**: Show system notification, navigate to request details on tap

---

## Testing Push Notifications

### 1. Manual Test via Firebase Console

1. Go to Firebase Console → Cloud Messaging
2. Create test message
3. Select target audience (specific user/topic)
4. Send test notification
5. Check device receives it

### 2. Verify Device Tokens are Saved

```
Firestore → users/{userId}/deviceTokens
```

Should show registered devices with active=true

### 3. Monitor Function Execution

```
Firebase Console → Functions → enrollmentNotifications
```

Check:
- Execution count
- Error rate
- Logs for specific requests

---

## Troubleshooting

### Notifications Not Received

**Checklist**:
1. ✅ firebase_messaging dependency added to pubspec.yaml
2. ✅ DeviceTokenService.initialize() called in main.dart
3. ✅ User has granted notification permissions (iOS)
4. ✅ Device token stored in Firestore (`/users/{userId}/deviceTokens/`)
5. ✅ Business owner's ID set in `/businesses/{businessId}/ownerUserId`
6. ✅ Android: Notification channel created (`enrollment_requests`)
7. ✅ Network connectivity available on device

### Check Device Token Registration

```dart
// In DeviceTokenService
final token = await FirebaseMessaging.instance.getToken();
print('Device Token: $token');

// Verify in Firestore
db.collection('users').doc(userId).collection('deviceTokens').get()
```

### Monitor Cloud Function Logs

```bash
firebase functions:log --follow
# Filter for: onEnrollmentRequestCreated
```

---

## Security Considerations

1. **Token Validation**: Invalid tokens automatically marked inactive
2. **User Authentication**: Only authenticated users can register tokens
3. **Permission Check**: Business owner verified before sending notifications
4. **Data Privacy**: Tenant phone/email only sent in notification context
5. **Token Cleanup**: Inactive tokens auto-deleted after 30 days

---

## Future Enhancements

- [ ] Multiple notification channels (high priority, promotions, etc.)
- [ ] Notification scheduling (quiet hours)
- [ ] Rich notifications with images
- [ ] Push notification analytics (open rates, dismissals)
- [ ] In-app notification preferences/settings
- [ ] Batch notifications (daily digest)
- [ ] Approval/rejection via notification action buttons
