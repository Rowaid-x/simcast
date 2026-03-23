"""Serializers for messages with encryption/decryption."""
import json

from rest_framework import serializers

from apps.users.serializers import UserSearchSerializer
from core.encryption import decrypt_message, encrypt_message
from .models import Message, MessageReadReceipt, MessageReaction


class MessageListSerializer(serializers.ModelSerializer):
    """
    Serializer for message list/detail views.

    Decrypts content on read and includes sender info and read status.
    """
    content = serializers.SerializerMethodField()
    sender = UserSearchSerializer(read_only=True)
    is_read = serializers.SerializerMethodField()
    reply_to_preview = serializers.SerializerMethodField()
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id', 'conversation_id', 'sender', 'content', 'message_type',
            'file_url', 'file_name', 'file_size', 'file_mime_type',
            'reply_to', 'reply_to_preview', 'expires_at', 'is_deleted',
            'is_read', 'reactions', 'created_at',
        ]
        read_only_fields = fields

    def get_content(self, obj):
        """Decrypt message content for display."""
        if obj.is_deleted:
            return None
        try:
            return decrypt_message(
                bytes(obj.content_encrypted),
                bytes(obj.content_nonce),
            )
        except Exception:
            return '[Decryption error]'

    def get_is_read(self, obj):
        """Check if the message has been read by the other party."""
        request = self.context.get('request')
        if not request or not request.user:
            return False
        return obj.read_receipts.exclude(user=obj.sender).exists()

    def get_reply_to_preview(self, obj):
        """Get a brief preview of the replied-to message."""
        if not obj.reply_to or obj.reply_to.is_deleted:
            return None
        try:
            content = decrypt_message(
                bytes(obj.reply_to.content_encrypted),
                bytes(obj.reply_to.content_nonce),
            )
            return {
                'id': str(obj.reply_to.id),
                'content': content[:100] if content else None,
                'sender_name': obj.reply_to.sender.display_name if obj.reply_to.sender else None,
                'message_type': obj.reply_to.message_type,
            }
        except Exception:
            return None

    def get_reactions(self, obj):
        """Return flat list of reactions with user info."""
        return [
            {
                'emoji': r.emoji,
                'user_id': str(r.user_id),
                'user_display_name': r.user.display_name if r.user else 'Unknown',
            }
            for r in obj.reactions.select_related('user').all()
        ]


class CreateMessageSerializer(serializers.Serializer):
    """
    Serializer for creating a new message.

    Encrypts content before storage.
    """
    content = serializers.CharField(max_length=5000)
    message_type = serializers.ChoiceField(
        choices=['text', 'image', 'voice', 'video', 'file'],
        default='text',
    )
    reply_to = serializers.UUIDField(required=False, allow_null=True)
    file_url = serializers.URLField(required=False, allow_null=True, allow_blank=True)
    file_name = serializers.CharField(required=False, allow_null=True, allow_blank=True, max_length=255)
    file_size = serializers.IntegerField(required=False, allow_null=True)
    file_mime_type = serializers.CharField(required=False, allow_null=True, allow_blank=True, max_length=100)

    def validate_content(self, value):
        """Strip HTML tags and validate content length."""
        import re
        clean = re.sub(r'<[^>]+>', '', value)
        if not clean.strip():
            raise serializers.ValidationError('Message content cannot be empty.')
        return clean.strip()

    def create(self, validated_data):
        """Encrypt content and create the message."""
        content = validated_data.pop('content')
        ciphertext, nonce = encrypt_message(content)

        reply_to_id = validated_data.pop('reply_to', None)

        message = Message.objects.create(
            content_encrypted=ciphertext,
            content_nonce=nonce,
            reply_to_id=reply_to_id,
            **validated_data,
        )
        return message
