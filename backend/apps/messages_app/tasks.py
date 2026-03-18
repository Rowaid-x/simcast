"""Celery tasks for message auto-deletion."""
import os
import logging

from celery import shared_task
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


@shared_task(name='messages.auto_delete_expired')
def auto_delete_expired_messages():
    """
    Scheduled task that runs every 60 seconds to delete expired messages.

    - Finds messages where expires_at <= now and is_deleted = False
    - Wipes encrypted content and file references
    - Deletes associated files from filesystem
    - Broadcasts deletion events via WebSocket to connected clients
    """
    from apps.messages_app.models import Message

    now = timezone.now()
    expired_messages = Message.objects.filter(
        expires_at__lte=now,
        is_deleted=False,
    ).select_related('conversation')

    if not expired_messages.exists():
        return 'No expired messages found.'

    # Group by conversation for WebSocket broadcast
    conversation_message_ids = {}
    file_paths_to_delete = []

    for msg in expired_messages:
        conv_id = str(msg.conversation_id)
        if conv_id not in conversation_message_ids:
            conversation_message_ids[conv_id] = []
        conversation_message_ids[conv_id].append(str(msg.id))

        # Collect file paths for deletion
        if msg.file_url:
            # Extract relative path from URL and build filesystem path
            try:
                media_url = settings.MEDIA_URL
                if media_url in msg.file_url:
                    relative_path = msg.file_url.split(media_url)[-1]
                    full_path = os.path.join(settings.MEDIA_ROOT, relative_path)
                    file_paths_to_delete.append(full_path)
            except Exception as e:
                logger.warning(f"Could not parse file path for message {msg.id}: {e}")

    # Bulk update: wipe content and mark as deleted
    count = expired_messages.update(
        is_deleted=True,
        content_encrypted=b'',
        content_nonce=b'',
        file_url=None,
    )

    # Delete physical files
    for file_path in file_paths_to_delete:
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.info(f"Deleted file: {file_path}")
        except OSError as e:
            logger.warning(f"Could not delete file {file_path}: {e}")

    # Broadcast deletion events via WebSocket
    channel_layer = get_channel_layer()
    if channel_layer:
        for conv_id, message_ids in conversation_message_ids.items():
            try:
                async_to_sync(channel_layer.group_send)(
                    f"conversation_{conv_id}",
                    {
                        'type': 'chat_deleted',
                        'conversation_id': conv_id,
                        'message_ids': message_ids,
                    }
                )
            except Exception as e:
                logger.warning(f"Could not broadcast deletion for conversation {conv_id}: {e}")

    logger.info(f"Auto-deleted {count} expired messages across {len(conversation_message_ids)} conversations.")
    return f'Deleted {count} expired messages.'
