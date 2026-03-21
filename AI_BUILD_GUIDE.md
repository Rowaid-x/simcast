# AI Build Guide — Flutter + Django Full-Stack Apps

> **Purpose**: This document captures hard-won lessons from building and deploying the Whisper/SimCast app. Include this file in any new project so the AI assistant avoids the same pitfalls and follows proven patterns.

---

## Table of Contents

1. [Repository Structure](#1-repository-structure)
2. [Git Branch Strategy](#2-git-branch-strategy)
3. [Backend (Django)](#3-backend-django)
4. [Flutter App](#4-flutter-app)
5. [Push Notifications (FCM + APNs)](#5-push-notifications-fcm--apns)
6. [Codemagic CI/CD (iOS)](#6-codemagic-cicd-ios)
7. [Docker & Server Deployment](#7-docker--server-deployment)
8. [WebSocket Real-Time](#8-websocket-real-time)
9. [Common Pitfalls & Fixes](#9-common-pitfalls--fixes)
10. [Checklist Before First Deploy](#10-checklist-before-first-deploy)

---

## 1. Repository Structure

```
project-root/
├── backend/                    # Django project
│   ├── apps/                   # Django apps (users, conversations, messages, ws)
│   ├── core/                   # Shared utilities (encryption, notifications, pagination, throttles)
│   ├── whisper/                # Django project config (settings, urls, asgi, wsgi, celery)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── manage.py
├── flutter_app/                # Flutter project
│   ├── lib/
│   │   ├── config/             # Theme, routes, constants
│   │   ├── core/               # API client, WebSocket, storage, services
│   │   ├── features/           # Feature modules (auth, chat, conversations, profile, settings)
│   │   ├── models/             # Data models
│   │   └── widgets/            # Shared widgets
│   ├── firebase/               # GoogleService-Info.plist (iOS) goes here
│   ├── pubspec.yaml
│   └── analysis_options.yaml
├── nginx/
│   └── nginx.conf
├── docker-compose.yml
├── codemagic.yaml              # Codemagic CI/CD config
├── .env.example
└── AI_BUILD_GUIDE.md           # This file
```

**Key rules:**
- Keep `backend/` and `flutter_app/` as siblings in the same repo
- The `codemagic.yaml` goes at the **repo root**, not inside `flutter_app/`
- Firebase credentials JSON goes at repo root or `backend/` — **never commit private keys**; use `.gitignore` and copy them to the server manually
- `GoogleService-Info.plist` goes in `flutter_app/firebase/` and is copied to `ios/Runner/` during CI build

---

## 2. Git Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Backend code, infrastructure, docker-compose, nginx |
| `FE-<appname>` | Flutter frontend code + codemagic.yaml |

- Codemagic triggers on the **frontend branch** (e.g., `FE-simcast`)
- Backend deploys from `main` via `git pull` on the server
- When backend changes affect the frontend (new API endpoints), merge `main` into the FE branch or keep them in sync
- **Never force-push** to the FE branch while a Codemagic build is running

---

## 3. Backend (Django)

### Custom User Model

```python
# Always use UUID primary key and email-based auth
class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    USERNAME_FIELD = 'email'
    device_token = models.CharField(max_length=500, blank=True, null=True)
```

**CRITICAL**: Always define a custom `UserManager` with `create_user()` and `create_superuser()` that accept `email` as the first argument. Django's default manager expects `username`, which will cause `TypeError` on registration if you use `USERNAME_FIELD = 'email'`.

### UUID Serialization

When sending UUIDs over WebSocket (JSON), **always cast to string**:
```python
'conversation_id': str(conversation.id)  # NOT conversation.id
'user_id': str(self.user.id)             # NOT self.user.id
```

UUID objects are not JSON-serializable. This causes silent WebSocket crashes.

### Field Naming Consistency

Pick one name and stick with it across the entire stack:
- If the model field is `device_token`, the API endpoint should accept `device_token`, the Flutter code should send `device_token`, and the WebSocket consumer should read `user.device_token`
- A mismatch like `fcm_device_token` in one place and `device_token` in another causes `AttributeError` at runtime

### Settings.py Essentials

```python
# Always include these
FIREBASE_CREDENTIALS_PATH = os.environ.get('FIREBASE_CREDENTIALS_PATH', '')
MESSAGE_ENCRYPTION_KEY = os.environ.get('MESSAGE_ENCRYPTION_KEY', '')

# For development/HTTP servers (no HTTPS):
# DEBUG = True
# SECURE_SSL_REDIRECT must be False or absent when not using HTTPS
```

---

## 4. Flutter App

### State Management: Riverpod

- Use `StateNotifierProvider` for complex state, `StateProvider` for simple values
- Use `autoDispose` on chat providers so they clean up when leaving a screen
- Always add `mounted` guards before calling `setState` or `ref.read` after async operations

### API Client (Dio)

```dart
// JWT interceptor must handle token refresh automatically
// Include retry logic: when a 401 is received, refresh the token and retry once
// Store tokens in FlutterSecureStorage, not SharedPreferences
```

### WebSocket Client

- Implement exponential backoff for reconnection (1s, 2s, 4s, 8s... max 30s)
- Always authenticate via query parameter: `ws://host/ws/chat/?token=<jwt>`
- Parse incoming JSON and route by `type` field (e.g., `chat.message`, `chat.typing`)

### Constants

```dart
class AppConstants {
  static const baseUrl = 'http://YOUR_SERVER_IP/api/v1';
  static const wsUrl = 'ws://YOUR_SERVER_IP/ws/chat/';
}
```

**No trailing slash issues**: Django REST Framework expects trailing slashes by default. Always include them in endpoint paths: `/users/me/`, not `/users/me`.

---

## 5. Push Notifications (FCM + APNs)

### This is the hardest part. Follow these steps exactly.

### A. Firebase Console Setup

1. Create Firebase project
2. Add iOS app with your **exact bundle ID** (e.g., `com.yourname.appname`)
3. Download `GoogleService-Info.plist` → put in `flutter_app/firebase/`
4. Go to **Project Settings → Service Accounts** → Generate new private key → download JSON
5. Go to **Project Settings → Cloud Messaging**:
   - Upload APNs Authentication Key (.p8) from Apple Developer portal
   - Enter **Key ID** (from Apple → Keys page)
   - Enter **Team ID** (from Apple → Membership page)
   - **CRITICAL: Select "Production" APNs environment**, NOT "Development"
   - Development is ONLY for apps run directly from Xcode. TestFlight and App Store builds use Production.

### B. Apple Developer Portal Setup

1. Go to **Identifiers** → Select your App ID → Enable **Push Notifications** capability
2. Go to **Keys** → Create a new key → Enable **Apple Push Notifications service (APNs)**
3. Download the `.p8` file (you can only download it once!)
4. Note the **Key ID** (shown on the Keys page)

### C. Backend: Use google.auth, NOT firebase_admin SDK

The `firebase_admin` Python SDK (v6.x) has a bug where `messaging.send()` fails with `401 Unauthorized` even though the credentials are valid. The `dry_run=True` works but real sends fail.

**Solution**: Use `google.oauth2` + `AuthorizedSession` directly:

```python
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession
import json

_session = None
_project_id = None

def _init_fcm():
    global _session, _project_id
    if _session is not None:
        return
    creds = service_account.Credentials.from_service_account_file(
        settings.FIREBASE_CREDENTIALS_PATH,
        scopes=[
            'https://www.googleapis.com/auth/firebase.messaging',
            'https://www.googleapis.com/auth/cloud-platform',
        ],
    )
    _session = AuthorizedSession(creds)
    with open(settings.FIREBASE_CREDENTIALS_PATH) as f:
        _project_id = json.load(f).get('project_id')

def send_push_notification(device_token, title, body, data=None):
    _init_fcm()
    url = f'https://fcm.googleapis.com/v1/projects/{_project_id}/messages:send'
    resp = _session.post(url, json={
        'message': {
            'token': device_token,
            'notification': {'title': title, 'body': body},
            'data': {k: str(v) for k, v in (data or {}).items()},
            'apns': {
                'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
                'payload': {'aps': {'sound': 'default', 'badge': 1, 'content-available': 1}},
            },
        }
    })
    return resp.status_code == 200
```

### D. Flutter: APNs Token Timing (iOS)

On iOS, the APNs token must be available **before** requesting the FCM token. Add a retry loop:

```dart
if (Platform.isIOS) {
  String? apnsToken;
  for (int i = 0; i < 10; i++) {
    apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    if (apnsToken != null) break;
    await Future.delayed(const Duration(seconds: 1));
  }
  if (apnsToken == null) {
    debugPrint('WARNING: APNs token not available after 10s');
  }
}
// NOW get the FCM token
final fcmToken = await FirebaseMessaging.instance.getToken();
```

### E. Debugging Push Notifications

Add a temporary visible debug banner in the app (e.g., at the top of the conversations screen) that shows push status messages. This saves hours since you can't see console logs on TestFlight builds:

```dart
final pushDebugLogProvider = StateProvider<List<String>>((ref) => []);

// In your push service, log to this provider:
ref.read(pushDebugLogProvider.notifier).update((s) => [...s, 'APNs token OK']);

// In your UI, show the log:
Consumer(builder: (ctx, ref, _) {
  final logs = ref.watch(pushDebugLogProvider);
  return Container(
    color: Colors.black87,
    child: Text(logs.join('\n'), style: TextStyle(color: Colors.green, fontSize: 10)),
  );
})
```

Remove this banner after push notifications are confirmed working.

### F. Testing Push Without Rebuilding the App

Test from the server directly:

```bash
docker compose exec backend python -c "
import django,os; os.environ['DJANGO_SETTINGS_MODULE']='whisper.settings'; django.setup()
from core.notifications import send_push_notification
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.filter(email='test@example.com').first()
result = send_push_notification(user.device_token, 'Test', 'Hello!')
print(f'Result: {result}')
"
```

### G. Diagnostic Commands

```bash
# Check if tokens are saved
docker compose exec backend python -c "
import django,os; os.environ['DJANGO_SETTINGS_MODULE']='whisper.settings'; django.setup()
from django.contrib.auth import get_user_model
for u in get_user_model().objects.all():
    print(f'{u.display_name}: token={u.device_token}')
"

# Test Firebase credentials validity (should return 400 for fake token, not 401)
docker compose exec backend python -c "
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession, Request
creds = service_account.Credentials.from_service_account_file(
    '/app/firebase-credentials.json',
    scopes=['https://www.googleapis.com/auth/firebase.messaging']
)
creds.refresh(Request())
session = AuthorizedSession(creds)
resp = session.post(
    'https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send',
    json={'message': {'token': 'fake', 'notification': {'title': 'test', 'body': 'test'}}}
)
print(f'Status: {resp.status_code}')  # 400 = good (API works), 401 = bad (auth issue)
print(f'Response: {resp.text}')
"
```

---

## 6. Codemagic CI/CD (iOS)

### Proven codemagic.yaml Structure

```yaml
workflows:
  ios-workflow:
    name: iOS Build
    max_build_duration: 30
    instance_type: mac_mini_m2
    integrations:
      app_store_connect: YOUR_INTEGRATION_NAME
    environment:
      flutter: 3.32.0
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.yourname.appname
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: FE-appname
          include: true
    scripts:
      # Step 1: Install deps + generate iOS project
      - name: Install dependencies and generate iOS project
        script: |
          cd flutter_app
          flutter pub get
          flutter create --platforms ios .
          cp firebase/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist

      # Step 2: Fix bundle ID + deployment target
      - name: Set bundle ID and iOS deployment target
        script: |
          cd flutter_app/ios
          sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = com.yourname.appname;/g' Runner.xcodeproj/project.pbxproj
          sed -i '' 's/CODE_SIGN_STYLE = Automatic/CODE_SIGN_STYLE = Manual/g' Runner.xcodeproj/project.pbxproj
          sed -i '' '/^platform :ios/d' Podfile
          sed -i '' '1s/^/platform :ios, '\''15.0'\''\n/' Podfile
          sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = .*/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' Runner.xcodeproj/project.pbxproj

      # Step 3: Push notification entitlement (USE RUBY, NOT SED)
      - name: Add push notification entitlement
        script: |
          cd flutter_app/ios
          cat > Runner/Runner.entitlements << 'ENTITLEMENTS'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
                <key>aps-environment</key>
                <string>production</string>
          </dict>
          </plist>
          ENTITLEMENTS
          sed -i '' 's/^          //' Runner/Runner.entitlements

          # CRITICAL: Use xcodeproj gem to inject entitlement into Xcode project
          # sed-based approaches are UNRELIABLE for .pbxproj files
          gem install xcodeproj --no-document
          ruby <<'RUBY'
          require 'xcodeproj'
          project = Xcodeproj::Project.open('Runner.xcodeproj')
          project.targets.each do |target|
            next unless target.name == 'Runner'
            target.build_configurations.each do |config|
              config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
            end
          end
          project.save
          RUBY

      # Step 4: Info.plist privacy descriptions + ATS exception
      - name: Add privacy descriptions to Info.plist
        script: |
          cd flutter_app/ios/Runner
          /usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'Photo library access for sharing images.'" Info.plist || true
          /usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'Camera access for capturing photos.'" Info.plist || true
          /usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'Microphone access for voice messages.'" Info.plist || true
          /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" Info.plist || true
          # HTTP exception (remove when you have HTTPS)
          /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" Info.plist || true
          /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" Info.plist || true
          # Background modes for push
          /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" Info.plist || true
          /usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string remote-notification" Info.plist || true

      - name: Install CocoaPods
        script: cd flutter_app/ios && pod install

      - name: Set up code signing
        script: xcode-project use-profiles

      - name: Build iOS
        script: |
          cd flutter_app && flutter build ipa --release \
            --build-number=$(($(date +%s)/60)) \
            --export-options-plist=/Users/builder/export_options.plist

    artifacts:
      - flutter_app/build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

### Key Codemagic Lessons

1. **`flutter create --platforms ios .`** regenerates the iOS project fresh. This resets the bundle ID, so you MUST fix it in the next step.
2. **Never use `sed` to modify `.pbxproj` files** for build settings. The format is complex and sed breaks it. Use the `xcodeproj` Ruby gem instead.
3. **`CODE_SIGN_STYLE = Manual`** is required when using Codemagic's signing integration. Automatic signing conflicts with it.
4. **`GoogleService-Info.plist`** must be copied into `ios/Runner/` AFTER `flutter create` runs, because `flutter create` regenerates the `ios/` directory.
5. **Build number**: Use `$(($(date +%s)/60))` to auto-increment. TestFlight rejects duplicate build numbers.
6. **Stubbing problematic packages**: If a pub package (e.g., `record_linux`) has compilation errors on iOS, stub it out in CI. The package is only needed on Linux.

---

## 7. Docker & Server Deployment

### docker-compose.yml Services

| Service | Purpose | Port |
|---------|---------|------|
| db | PostgreSQL | 5432 (internal) |
| redis | Cache + Celery broker + Channels | 6379 (internal) |
| backend | Gunicorn (REST API) | 8000 (internal) |
| websocket | Daphne (WebSocket) | 8001 (internal) |
| celery | Background task worker | — |
| celery-beat | Periodic task scheduler | — |
| nginx | Reverse proxy | 80 (exposed) |

### Critical Docker Lessons

1. **Backend command must include `migrate`**:
   ```yaml
   command: sh -c "sleep 5 && python manage.py migrate && gunicorn whisper.wsgi:application --bind 0.0.0.0:8000 --workers 3"
   ```

2. **Use `sleep` to wait for DB**:
   - Backend: `sleep 5`
   - WebSocket: `sleep 10`
   - Celery: `sleep 15`

3. **Volume mount for live code updates**: Mount `./backend:/app` so you can `git pull` and restart without rebuilding.

4. **Firebase credentials**: Copy the JSON file to the server manually, then reference it in `.env`:
   ```
   FIREBASE_CREDENTIALS_PATH=/app/firebase-credentials.json
   ```

5. **Don't expose DB/Redis ports** to the host. Only nginx on port 80.

6. **Container name collisions**: If running multiple Docker Compose projects on the same server, service names like `db` can cause DNS conflicts. Either use explicit container names or separate Docker networks.

### Deploying Updates

```bash
cd /home/appname
git pull origin main
docker compose up -d --build backend websocket celery
```

No need to rebuild nginx, db, or redis for code changes.

---

## 8. WebSocket Real-Time

### Message Types

Define a clear protocol:

```python
# Client → Server
'chat.message'      # Send a message
'chat.typing'       # Typing indicator
'chat.read'         # Read receipt

# Server → Client
'chat.message'      # New message
'chat.typing'       # Someone is typing
'chat.read'         # Someone read a message
'chat.deleted'      # Messages auto-deleted
'chat.timer_update' # Auto-delete timer changed
'user.online'       # User online/offline status
```

### Broadcasting Changes from REST Views

When a REST API endpoint changes something that WebSocket clients need to know about (e.g., timer change), broadcast via the channel layer:

```python
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

channel_layer = get_channel_layer()
async_to_sync(channel_layer.group_send)(
    f'conversation_{conversation.id}',
    {
        'type': 'chat.timer_update',
        'conversation_id': str(conversation.id),
        'auto_delete_timer': new_timer,
    },
)
```

---

## 9. Common Pitfalls & Fixes

| Problem | Root Cause | Fix |
|---------|-----------|-----|
| `TypeError: create_user() missing 'username'` | Custom User with `USERNAME_FIELD = 'email'` but no custom UserManager | Add `UserManager` with email-based `create_user()` |
| UUID not JSON-serializable (WebSocket crash) | Sending `uuid.UUID` object instead of string | Always `str(uuid_field)` before sending over WebSocket |
| `AttributeError: 'User' has no attribute 'fcm_device_token'` | Field name mismatch between model and consumer | Use consistent field names everywhere |
| `401 THIRD_PARTY_AUTH_ERROR` from FCM | APNs key in Firebase set to "Development" instead of "Production" | Delete and re-upload as "Production" in Firebase Console |
| `401 Unauthorized` from `firebase_admin.messaging.send()` | Bug in firebase_admin SDK v6.x | Use `google.oauth2.service_account` + `AuthorizedSession` directly |
| `APNS token has not been set yet` on iOS | FCM token requested before APNs token is ready | Add retry loop: wait for APNs token first |
| Push entitlement not applied in Codemagic | Using `sed` on `.pbxproj` which is unreliable | Use `xcodeproj` Ruby gem |
| TestFlight build has no push permission | Missing entitlements file or not referenced in Xcode project | Verify `CODE_SIGN_ENTITLEMENTS` in build settings |
| `SECURE_SSL_REDIRECT` causes infinite redirect | Enabled in production mode but no HTTPS configured | Set `DEBUG=True` or disable SSL redirect until HTTPS is set up |
| Can't receive notifications on TestFlight | Using development APNs environment | Use production. TestFlight = production environment |

---

## 10. Checklist Before First Deploy

### Apple Developer Portal
- [ ] App ID created with Push Notifications enabled
- [ ] APNs Authentication Key (.p8) created and downloaded
- [ ] Note the Key ID and Team ID

### Firebase Console
- [ ] iOS app added with correct bundle ID
- [ ] `GoogleService-Info.plist` downloaded and placed in `flutter_app/firebase/`
- [ ] Service account key JSON downloaded
- [ ] APNs key uploaded as **Production** with correct Key ID and Team ID
- [ ] Cloud Messaging API (V1) enabled in Google Cloud Console

### Backend
- [ ] `FIREBASE_CREDENTIALS_PATH` set in `.env`
- [ ] `MESSAGE_ENCRYPTION_KEY` generated and set in `.env`
- [ ] `notifications.py` uses `google.auth` directly (not `firebase_admin` SDK)
- [ ] All UUID fields cast to `str()` in WebSocket consumer
- [ ] Custom `UserManager` defined with email-based `create_user()`

### Flutter App
- [ ] `firebase_options.dart` generated via FlutterFire CLI
- [ ] APNs token retry loop before FCM token request (iOS)
- [ ] Background message handler is a top-level function with `@pragma('vm:entry-point')`
- [ ] Device token registration endpoint matches backend field name

### Codemagic
- [ ] `codemagic.yaml` at repo root
- [ ] Uses `xcodeproj` gem for entitlement injection (not sed)
- [ ] `GoogleService-Info.plist` copied after `flutter create`
- [ ] Bundle ID fixed after `flutter create`
- [ ] Privacy descriptions added to Info.plist
- [ ] Background modes enabled for `remote-notification`

### Server
- [ ] Firebase credentials JSON copied to server
- [ ] `.env` file configured with all required variables
- [ ] `docker compose up -d --build` runs without errors
- [ ] Migrations run automatically on startup
- [ ] Test push notification returns 200 from server

---

*Last updated: March 2026 — Based on lessons from building SimCast/Whisper*
