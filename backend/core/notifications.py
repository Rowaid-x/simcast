"""
FCM push notification service for Whisper.

Sends push notifications to offline users when they receive new messages.
Uses Google Auth directly for reliable FCM v1 API access.
"""
import json
import logging

from django.conf import settings

logger = logging.getLogger(__name__)

# Lazy-initialize credentials
_session = None
_project_id = None


def _init_fcm():
    """Initialize Google Auth session for FCM v1 API."""
    global _session, _project_id
    if _session is not None:
        return

    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import AuthorizedSession

        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
        if not cred_path:
            logger.warning("FIREBASE_CREDENTIALS_PATH not set.")
            return

        creds = service_account.Credentials.from_service_account_file(
            cred_path,
            scopes=[
                'https://www.googleapis.com/auth/firebase.messaging',
                'https://www.googleapis.com/auth/cloud-platform',
            ],
        )
        _session = AuthorizedSession(creds)

        # Extract project_id from credentials file
        with open(cred_path) as f:
            _project_id = json.load(f).get('project_id')

        logger.info("FCM initialized successfully (project: %s)", _project_id)
    except Exception as e:
        logger.warning("FCM initialization failed: %s", e)


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """
    Send a push notification to a single device via FCM v1 API.

    Args:
        device_token: The FCM registration token for the target device.
        title: Notification title.
        body: Notification body text.
        data: Optional data payload dict.

    Returns:
        True if sent successfully, False otherwise.
    """
    _init_fcm()

    if _session is None or _project_id is None:
        logger.warning("FCM not initialized, skipping push.")
        return False

    try:
        payload = {
            'message': {
                'token': device_token,
                'notification': {'title': title, 'body': body},
                'data': {k: str(v) for k, v in (data or {}).items()},
                'android': {
                    'priority': 'HIGH',
                    'notification': {
                        'channel_id': 'whisper_messages',
                        'sound': 'default',
                    },
                },
                'apns': {
                    'headers': {
                        'apns-priority': '10',
                        'apns-push-type': 'alert',
                    },
                    'payload': {
                        'aps': {
                            'sound': 'default',
                            'badge': 1,
                            'content-available': 1,
                        }
                    },
                },
            }
        }

        url = f'https://fcm.googleapis.com/v1/projects/{_project_id}/messages:send'
        resp = _session.post(url, json=payload)

        if resp.status_code == 200:
            msg_id = resp.json().get('name', '')
            logger.info("FCM notification sent: %s", msg_id)
            return True
        else:
            logger.warning("FCM send failed (%s): %s", resp.status_code, resp.text)
            return False

    except Exception as e:
        logger.warning("Failed to send FCM notification to %s: %s", device_token, e)
        return False


def send_new_message_notification(
    recipient_device_token: str,
    sender_name: str,
    conversation_id: str,
    message_preview: str,
    conversation_type: str = 'direct',
    group_name: str | None = None,
):
    """
    Send a push notification for a new chat message.

    Args:
        recipient_device_token: FCM token of the recipient.
        sender_name: Display name of the message sender.
        conversation_id: UUID of the conversation.
        message_preview: Truncated preview of the message content.
        conversation_type: 'direct' or 'group'.
        group_name: Name of the group (if group chat).
    """
    if not recipient_device_token:
        return

    if conversation_type == 'group' and group_name:
        title = group_name
        body = f'{sender_name}: {message_preview}'
    else:
        title = sender_name
        body = message_preview

    # Truncate body to 200 chars
    if len(body) > 200:
        body = body[:197] + '...'

    send_push_notification(
        device_token=recipient_device_token,
        title=title,
        body=body,
        data={
            'type': 'new_message',
            'conversation_id': conversation_id,
            'conversation_type': conversation_type,
        },
    )
