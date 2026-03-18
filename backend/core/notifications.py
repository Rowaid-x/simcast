"""
FCM push notification service for Whisper.

Sends push notifications to offline users when they receive new messages.
"""
import logging

from django.conf import settings

logger = logging.getLogger(__name__)

# Lazy-initialize Firebase Admin SDK
_firebase_app = None


def _init_firebase():
    """Initialize the Firebase Admin SDK if not already done."""
    global _firebase_app
    if _firebase_app is not None:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
        if cred_path:
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            # Fall back to environment-based default credentials
            _firebase_app = firebase_admin.initialize_app()
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.warning(f"Firebase Admin SDK initialization failed: {e}")


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """
    Send a push notification to a single device via FCM.

    Args:
        device_token: The FCM registration token for the target device.
        title: Notification title.
        body: Notification body text.
        data: Optional data payload dict.

    Returns:
        True if sent successfully, False otherwise.
    """
    _init_firebase()

    try:
        from firebase_admin import messaging

        notification = messaging.Notification(
            title=title,
            body=body,
        )

        message = messaging.Message(
            notification=notification,
            token=device_token,
            data=data or {},
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='whisper_messages',
                    sound='default',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    ),
                ),
            ),
        )

        response = messaging.send(message)
        logger.info(f"FCM notification sent: {response}")
        return True

    except Exception as e:
        logger.warning(f"Failed to send FCM notification to {device_token}: {e}")
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
