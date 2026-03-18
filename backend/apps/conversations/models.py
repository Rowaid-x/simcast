"""Models for conversations and conversation membership."""
import uuid
from django.conf import settings
from django.db import models


class Conversation(models.Model):
    """
    Represents a chat conversation (direct or group).

    Direct conversations have exactly 2 members.
    Group conversations can have multiple members with admin/member roles.
    """
    TYPE_CHOICES = [
        ('direct', 'Direct'),
        ('group', 'Group'),
    ]

    AUTO_DELETE_CHOICES = [
        (None, 'Off'),
        (1800, '30 minutes'),
        (3600, '1 hour'),
        (21600, '6 hours'),
        (86400, '24 hours'),
        (604800, '7 days'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    name = models.CharField(max_length=100, blank=True, null=True)
    avatar_url = models.URLField(max_length=500, blank=True, null=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_conversations',
    )
    auto_delete_timer = models.IntegerField(
        blank=True, null=True,
        choices=AUTO_DELETE_CHOICES,
        help_text='Auto-delete timer in seconds. NULL means off.',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    members = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        through='ConversationMember',
        related_name='conversations',
    )

    class Meta:
        db_table = 'conversations'
        ordering = ['-updated_at']

    def __str__(self):
        if self.type == 'group':
            return f"Group: {self.name or self.id}"
        return f"Direct: {self.id}"


class ConversationMember(models.Model):
    """Tracks membership and roles in conversations."""
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('member', 'Member'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='memberships',
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='conversation_memberships',
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)
    muted_until = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'conversation_members'
        unique_together = ['conversation', 'user']

    def __str__(self):
        return f"{self.user.display_name} in {self.conversation}"
