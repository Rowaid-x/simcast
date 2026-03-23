"""Models for messages and read receipts with server-side encryption."""
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone


class Message(models.Model):
    """
    Encrypted chat message.

    Content is encrypted at rest using AES-256-GCM.
    Each message has a unique nonce for encryption.
    Messages can auto-expire based on the conversation's auto_delete_timer.
    """
    TYPE_CHOICES = [
        ('text', 'Text'),
        ('image', 'Image'),
        ('voice', 'Voice'),
        ('video', 'Video'),
        ('file', 'File'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        'conversations.Conversation',
        on_delete=models.CASCADE,
        related_name='messages',
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='sent_messages',
    )
    reply_to = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies',
    )
    content_encrypted = models.BinaryField()
    content_nonce = models.BinaryField()
    message_type = models.CharField(max_length=10, choices=TYPE_CHOICES, default='text')
    file_url = models.URLField(max_length=500, blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True, null=True)
    file_size = models.IntegerField(blank=True, null=True)
    file_mime_type = models.CharField(max_length=100, blank=True, null=True)
    expires_at = models.DateTimeField(blank=True, null=True, db_index=True)
    is_deleted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'messages'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
            models.Index(
                fields=['expires_at'],
                condition=models.Q(expires_at__isnull=False, is_deleted=False),
                name='idx_messages_expiry',
            ),
        ]

    def __str__(self):
        return f"Message {self.id} in {self.conversation_id}"

    def save(self, *args, **kwargs):
        """Calculate expires_at based on conversation auto_delete_timer."""
        if not self.expires_at and not self.is_deleted:
            timer = self.conversation.auto_delete_timer
            if timer:
                created = self.created_at or timezone.now()
                self.expires_at = created + timedelta(seconds=timer)
        super().save(*args, **kwargs)


class MessageReadReceipt(models.Model):
    """Tracks which users have read which messages."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name='read_receipts',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='read_receipts',
    )
    read_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'message_read_receipts'
        unique_together = ['message', 'user']

    def __str__(self):
        return f"{self.user} read {self.message_id}"


class MessageReaction(models.Model):
    """Tracks emoji reactions on messages. One reaction per user per message."""
    ALLOWED_EMOJIS = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👎', '🎉', '😡']

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name='reactions',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='message_reactions',
    )
    emoji = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'message_reactions'
        unique_together = ['message', 'user']

    def __str__(self):
        return f"{self.user} reacted {self.emoji} on {self.message_id}"
