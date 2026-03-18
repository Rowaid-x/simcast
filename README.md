# Whisper — Secure Chat Application

A production-ready, security-focused mobile chat application with auto-deleting messages. Built with **Flutter** (frontend), **Django + DRF + Django Channels** (backend), and **PostgreSQL** (database).

## Features

- **1-on-1 and Group Chats** — Real-time messaging via WebSockets
- **Auto-Deleting Messages** — Configurable timers: 30 min, 1 hr, 6 hr, 24 hr, 7 days, or off
- **AES-256-GCM Encryption** — All messages encrypted at rest on the server
- **JWT Authentication** — Access + refresh tokens with automatic rotation
- **File Sharing** — Images, voice messages, and documents (up to 25MB)
- **Typing Indicators & Read Receipts** — Real-time presence
- **Online Status Tracking** — See who's active
- **Dark Luxury UI** — Minimal, premium design with smooth animations

## Architecture

```
Flutter App  →  Nginx (TLS/Rate Limit)  →  Gunicorn (REST) + Daphne (WebSocket)
                                              ↓
                                        Django Application
                                         ↓           ↓
                                     PostgreSQL     Redis
                                                      ↑
                                              Celery + Celery Beat
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Dart, Material 3 |
| Backend API | Django 5.x, Django REST Framework |
| Real-time | Django Channels, WebSockets, Redis |
| Database | PostgreSQL 15+ |
| Cache/Broker | Redis 7+ |
| Task Queue | Celery + Celery Beat |
| Containerization | Docker + Docker Compose |
| Reverse Proxy | Nginx |

## Project Structure

```
simcast/
├── backend/                    # Django backend
│   ├── apps/
│   │   ├── users/              # Custom User model, auth, profile
│   │   ├── conversations/      # Conversation CRUD, membership
│   │   ├── messages_app/       # Messages, encryption, auto-delete tasks
│   │   └── chat_ws/            # WebSocket consumer, JWT middleware
│   ├── core/
│   │   ├── encryption.py       # AES-256-GCM encrypt/decrypt
│   │   ├── exceptions.py       # Custom error handler
│   │   ├── pagination.py       # Cursor/offset pagination
│   │   └── throttles.py        # Rate limiting classes
│   ├── whisper/                # Django project settings
│   ├── Dockerfile
│   ├── manage.py
│   └── requirements.txt
├── flutter_app/                # Flutter mobile app
│   └── lib/
│       ├── config/             # Theme, routes, constants
│       ├── core/               # API client, WebSocket, storage, utils
│       ├── features/           # Auth, conversations, chat, profile, settings
│       ├── models/             # User, Conversation, Message
│       ├── widgets/            # Shared widgets (avatar, shimmer)
│       ├── main.dart
│       └── app.dart
├── nginx/                      # Nginx configuration
├── docker-compose.yml
└── .env.example
```

## Getting Started

### Prerequisites

- Python 3.12+
- PostgreSQL 15+
- Redis 7+
- Flutter 3.x SDK
- Docker & Docker Compose (for deployment)

### Backend Setup (Local Development)

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file and configure
cp .env.example .env
# Edit .env — set SECRET_KEY, DATABASE_URL, MESSAGE_ENCRYPTION_KEY

# Generate an encryption key
python -c "import os,base64; print(base64.b64encode(os.urandom(32)).decode())"
# Copy the output to MESSAGE_ENCRYPTION_KEY in .env

# Run migrations
python manage.py makemigrations users conversations messages_app
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Start the development server
python manage.py runserver

# In a separate terminal, start Daphne for WebSocket support:
daphne -p 8001 whisper.asgi:application

# In another terminal, start Celery worker + beat:
celery -A whisper worker -l info
celery -A whisper beat -l info
```

### Flutter Setup

```bash
cd flutter_app

# Get dependencies
flutter pub get

# Run code generation (for freezed/json_serializable if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# Update API URL in lib/config/constants.dart to point to your backend

# Run on a device or emulator
flutter run
```

### Docker Deployment

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env with production values

# Build and start all services
docker-compose up -d --build

# Run migrations inside the backend container
docker-compose exec backend python manage.py migrate

# Create superuser
docker-compose exec backend python manage.py createsuperuser
```

## Security Features

- **Argon2id** password hashing (Django default override)
- **JWT tokens**: 15-min access, 7-day refresh with rotation + blacklisting
- **AES-256-GCM** encryption for all message content at rest
- **Rate limiting**: Login (5/min), Registration (3/hr), Messages (30/min), Uploads (10/min)
- **File validation**: MIME type checking, 25MB limit, randomized filenames
- **Input sanitization**: HTML stripping on all text inputs
- **Transport security**: TLS 1.3 via Nginx, HSTS, security headers
- **Token storage**: Flutter Secure Storage (Keychain / EncryptedSharedPreferences)
- **WebSocket auth**: JWT token validation on connection handshake

## API Endpoints

### Authentication
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register/` | Register new account |
| POST | `/api/v1/auth/login/` | Login |
| POST | `/api/v1/auth/token/refresh/` | Refresh JWT tokens |
| POST | `/api/v1/auth/logout/` | Blacklist refresh token |
| POST | `/api/v1/auth/change-password/` | Change password |

### Users
| Method | Path | Description |
|--------|------|-------------|
| GET/PATCH | `/api/v1/users/me/` | Profile |
| GET | `/api/v1/users/search/?q=` | Search users |
| POST | `/api/v1/users/me/device-token/` | Register FCM token |

### Conversations
| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `/api/v1/conversations/` | List / Create |
| GET/PATCH/DELETE | `/api/v1/conversations/{id}/` | Detail / Update / Leave |
| POST | `/api/v1/conversations/{id}/members/` | Add members |
| DELETE | `/api/v1/conversations/{id}/members/{uid}/` | Remove member |

### Messages
| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `/api/v1/conversations/{id}/messages/` | List / Send |
| DELETE | `/api/v1/messages/{id}/` | Delete message |
| POST | `/api/v1/messages/{id}/read/` | Mark as read |
| POST | `/api/v1/upload/` | Upload file |

### WebSocket
```
WSS /ws/chat/?token=<jwt_access_token>
```

## Auto-Delete System

Messages auto-delete based on the conversation's configured timer. A Celery Beat task runs every 60 seconds to:

1. Find messages where `expires_at <= now` and `is_deleted = False`
2. Wipe encrypted content (`content_encrypted`, `content_nonce` set to empty bytes)
3. Remove associated files from the filesystem
4. Broadcast deletion events via WebSocket to connected clients

When a conversation's timer changes, `expires_at` is recalculated for all existing messages.

## Running Tests

```bash
cd backend
python manage.py test apps.messages_app.tests -v 2
```

## License

Private — All rights reserved.
