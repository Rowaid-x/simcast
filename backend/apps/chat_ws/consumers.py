"""WebSocket consumer for real-time chat functionality."""
import json
from datetime import timedelta

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

User = get_user_model()


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """
    Main WebSocket consumer handling real-time chat operations.

    Handles:
    - Message sending/receiving
    - Typing indicators
    - Read receipts
    - Online status tracking
    - Auto-delete broadcast events
    """

    async def connect(self):
        """Authenticate and subscribe user to all their conversation groups."""
        self.user = self.scope.get('user', AnonymousUser())

        if isinstance(self.user, AnonymousUser) or not self.user.is_authenticated:
            await self.close(code=4001)
            return

        # Join a personal channel for direct notifications
        self.user_group = f"user_{self.user.id}"
        await self.channel_layer.group_add(self.user_group, self.channel_name)

        # Join all conversation groups
        self.conversation_groups = []
        conversation_ids = await self._get_user_conversation_ids()
        for conv_id in conversation_ids:
            group_name = f"conversation_{conv_id}"
            await self.channel_layer.group_add(group_name, self.channel_name)
            self.conversation_groups.append(group_name)

        # Set user online
        await self._set_online_status(True)

        # Broadcast online status to all conversation members
        for group in self.conversation_groups:
            await self.channel_layer.group_send(group, {
                'type': 'user_online',
                'user_id': str(self.user.id),
                'is_online': True,
            })

        await self.accept()

    async def disconnect(self, close_code):
        """Clean up on disconnect: update status, leave groups."""
        if hasattr(self, 'user') and self.user.is_authenticated:
            await self._set_online_status(False)

            # Broadcast offline status
            for group in getattr(self, 'conversation_groups', []):
                await self.channel_layer.group_send(group, {
                    'type': 'user_online',
                    'user_id': str(self.user.id),
                    'is_online': False,
                })
                await self.channel_layer.group_discard(group, self.channel_name)

            if hasattr(self, 'user_group'):
                await self.channel_layer.group_discard(self.user_group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Route incoming messages to the appropriate handler."""
        msg_type = content.get('type')

        handlers = {
            'chat.message': self._handle_chat_message,
            'chat.typing': self._handle_typing,
            'chat.read': self._handle_read_receipt,
        }

        handler = handlers.get(msg_type)
        if handler:
            await handler(content)

    async def _handle_chat_message(self, content):
        """Process and broadcast a new chat message."""
        conversation_id = content.get('conversation_id')
        text_content = content.get('content', '').strip()
        message_type = content.get('message_type', 'text')
        reply_to = content.get('reply_to')
        file_url = content.get('file_url')
        file_name = content.get('file_name')
        file_size = content.get('file_size')
        file_mime_type = content.get('file_mime_type')

        if not conversation_id or not text_content:
            return

        # Verify membership and create the encrypted message
        message_data = await self._create_message(
            conversation_id=conversation_id,
            content=text_content,
            message_type=message_type,
            reply_to=reply_to,
            file_url=file_url,
            file_name=file_name,
            file_size=file_size,
            file_mime_type=file_mime_type,
        )

        if message_data is None:
            return

        # Broadcast to conversation group
        group_name = f"conversation_{conversation_id}"
        await self.channel_layer.group_send(group_name, {
            'type': 'chat_message',
            'message': message_data,
        })

    async def _handle_typing(self, content):
        """Broadcast typing indicator to conversation group."""
        conversation_id = content.get('conversation_id')
        is_typing = content.get('is_typing', False)

        if not conversation_id:
            return

        group_name = f"conversation_{conversation_id}"
        await self.channel_layer.group_send(group_name, {
            'type': 'chat_typing',
            'conversation_id': conversation_id,
            'user_id': str(self.user.id),
            'display_name': self.user.display_name,
            'is_typing': is_typing,
        })

    async def _handle_read_receipt(self, content):
        """Process read receipt and broadcast to conversation."""
        conversation_id = content.get('conversation_id')
        message_id = content.get('message_id')

        if not conversation_id or not message_id:
            return

        await self._mark_message_read(message_id)

        group_name = f"conversation_{conversation_id}"
        await self.channel_layer.group_send(group_name, {
            'type': 'chat_read',
            'conversation_id': conversation_id,
            'user_id': str(self.user.id),
            'message_id': message_id,
        })

    # --- Channel layer event handlers (Server → Client) ---

    async def chat_message(self, event):
        """Send a new message to the client."""
        await self.send_json({
            'type': 'chat.message',
            'message': event['message'],
        })

    async def chat_typing(self, event):
        """Send typing indicator to the client (skip sender)."""
        if event['user_id'] == str(self.user.id):
            return
        await self.send_json({
            'type': 'chat.typing',
            'conversation_id': event['conversation_id'],
            'user_id': event['user_id'],
            'display_name': event.get('display_name', ''),
            'is_typing': event['is_typing'],
        })

    async def chat_read(self, event):
        """Send read receipt to the client."""
        await self.send_json({
            'type': 'chat.read',
            'conversation_id': event['conversation_id'],
            'user_id': event['user_id'],
            'message_id': event['message_id'],
        })

    async def chat_deleted(self, event):
        """Send message deletion notification to the client."""
        await self.send_json({
            'type': 'chat.deleted',
            'conversation_id': event['conversation_id'],
            'message_ids': event['message_ids'],
        })

    async def user_online(self, event):
        """Send online status change to the client."""
        if event['user_id'] == str(self.user.id):
            return
        await self.send_json({
            'type': 'user.online',
            'user_id': event['user_id'],
            'is_online': event['is_online'],
        })

    # --- Database operations (sync wrapped) ---

    @database_sync_to_async
    def _get_user_conversation_ids(self):
        """Get all conversation IDs for the current user."""
        from apps.conversations.models import ConversationMember
        return list(
            ConversationMember.objects.filter(user=self.user)
            .values_list('conversation_id', flat=True)
        )

    @database_sync_to_async
    def _set_online_status(self, is_online):
        """Update user's online status and last_seen timestamp."""
        User.objects.filter(id=self.user.id).update(
            is_online=is_online,
            last_seen=timezone.now(),
        )

    @database_sync_to_async
    def _create_message(self, conversation_id, content, message_type, reply_to,
                        file_url, file_name, file_size, file_mime_type):
        """Create an encrypted message and return serialized data."""
        import re
        from apps.conversations.models import Conversation, ConversationMember
        from apps.messages_app.models import Message
        from apps.messages_app.serializers import MessageListSerializer
        from core.encryption import encrypt_message

        # Verify membership
        if not ConversationMember.objects.filter(
            conversation_id=conversation_id, user=self.user
        ).exists():
            return None

        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return None

        # Sanitize content
        clean_content = re.sub(r'<[^>]+>', '', content).strip()
        if not clean_content:
            return None

        # Encrypt
        ciphertext, nonce = encrypt_message(clean_content)

        # Calculate expiry
        expires_at = None
        if conversation.auto_delete_timer:
            expires_at = timezone.now() + timedelta(seconds=conversation.auto_delete_timer)

        message = Message.objects.create(
            conversation=conversation,
            sender=self.user,
            content_encrypted=ciphertext,
            content_nonce=nonce,
            message_type=message_type,
            reply_to_id=reply_to,
            file_url=file_url,
            file_name=file_name,
            file_size=file_size,
            file_mime_type=file_mime_type,
            expires_at=expires_at,
        )

        # Update conversation timestamp
        conversation.save(update_fields=['updated_at'])

        # Send push notifications to offline members
        self._send_push_to_offline_members(
            conversation=conversation,
            sender=self.user,
            content_preview=clean_content,
        )

        # Serialize for broadcast
        serializer = MessageListSerializer(message)
        return serializer.data

    @staticmethod
    def _send_push_to_offline_members(conversation, sender, content_preview):
        """Send FCM push notifications to offline conversation members."""
        from apps.conversations.models import ConversationMember
        from core.notifications import send_new_message_notification

        offline_members = ConversationMember.objects.filter(
            conversation=conversation,
        ).exclude(user=sender).select_related('user')

        for member in offline_members:
            user = member.user
            if not user.is_online and user.device_token:
                send_new_message_notification(
                    recipient_device_token=user.device_token,
                    sender_name=sender.display_name,
                    conversation_id=str(conversation.id),
                    message_preview=content_preview[:100],
                    conversation_type=conversation.type,
                    group_name=conversation.name if conversation.type == 'group' else None,
                )

    @database_sync_to_async
    def _mark_message_read(self, message_id):
        """Create a read receipt for a message."""
        from apps.messages_app.models import Message, MessageReadReceipt
        try:
            message = Message.objects.get(id=message_id)
            MessageReadReceipt.objects.get_or_create(
                message=message,
                user=self.user,
            )
        except Message.DoesNotExist:
            pass
