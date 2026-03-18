"""Serializers for conversations and membership management."""
from django.contrib.auth import get_user_model
from django.db.models import Q
from rest_framework import serializers

from apps.users.serializers import UserSearchSerializer
from .models import Conversation, ConversationMember

User = get_user_model()


class ConversationMemberSerializer(serializers.ModelSerializer):
    """Serializer for conversation membership details."""
    user = UserSearchSerializer(read_only=True)

    class Meta:
        model = ConversationMember
        fields = ['id', 'user', 'role', 'joined_at', 'muted_until']
        read_only_fields = ['id', 'joined_at']


class ConversationListSerializer(serializers.ModelSerializer):
    """
    Serializer for the conversations list view.

    Includes last message preview and unread count.
    """
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    other_user = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'type', 'name', 'avatar_url', 'auto_delete_timer',
            'last_message', 'unread_count', 'other_user', 'member_count',
            'created_at', 'updated_at',
        ]

    def get_last_message(self, obj):
        """Get the most recent message preview for this conversation."""
        from apps.messages_app.serializers import MessageListSerializer
        last_msg = obj.messages.filter(is_deleted=False).order_by('-created_at').first()
        if last_msg:
            return MessageListSerializer(last_msg, context=self.context).data
        return None

    def get_unread_count(self, obj):
        """Count unread messages for the requesting user."""
        user = self.context['request'].user
        from apps.messages_app.models import Message, MessageReadReceipt
        return Message.objects.filter(
            conversation=obj,
            is_deleted=False,
        ).exclude(
            sender=user,
        ).exclude(
            read_receipts__user=user,
        ).count()

    def get_other_user(self, obj):
        """For direct conversations, return the other user's info."""
        if obj.type != 'direct':
            return None
        user = self.context['request'].user
        other_member = obj.memberships.exclude(user=user).select_related('user').first()
        if other_member:
            return UserSearchSerializer(other_member.user).data
        return None

    def get_member_count(self, obj):
        """Return the number of members in the conversation."""
        return obj.memberships.count()


class ConversationDetailSerializer(serializers.ModelSerializer):
    """Detailed conversation serializer including all members."""
    members = serializers.SerializerMethodField()
    other_user = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'type', 'name', 'avatar_url', 'auto_delete_timer',
            'created_by', 'members', 'other_user', 'created_at', 'updated_at',
        ]

    def get_members(self, obj):
        memberships = obj.memberships.select_related('user').all()
        return ConversationMemberSerializer(memberships, many=True).data

    def get_other_user(self, obj):
        if obj.type != 'direct':
            return None
        user = self.context['request'].user
        other_member = obj.memberships.exclude(user=user).select_related('user').first()
        if other_member:
            return UserSearchSerializer(other_member.user).data
        return None


class CreateDirectConversationSerializer(serializers.Serializer):
    """Serializer for creating a direct (1-on-1) conversation."""
    user_id = serializers.UUIDField()

    def validate_user_id(self, value):
        try:
            User.objects.get(id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError('User not found.')
        return value


class CreateGroupConversationSerializer(serializers.Serializer):
    """Serializer for creating a group conversation."""
    name = serializers.CharField(max_length=100)
    member_ids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=1,
        max_length=100,
    )

    def validate_member_ids(self, value):
        users = User.objects.filter(id__in=value)
        if users.count() != len(value):
            raise serializers.ValidationError('One or more users not found.')
        return value


class UpdateConversationSerializer(serializers.ModelSerializer):
    """Serializer for updating conversation settings."""

    class Meta:
        model = Conversation
        fields = ['name', 'avatar_url', 'auto_delete_timer']

    def validate_auto_delete_timer(self, value):
        valid_values = [None, 1800, 3600, 21600, 86400, 604800]
        if value not in valid_values:
            raise serializers.ValidationError(
                f'Invalid timer value. Must be one of: {valid_values}'
            )
        return value


class AddMembersSerializer(serializers.Serializer):
    """Serializer for adding members to a group conversation."""
    user_ids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=1,
        max_length=50,
    )
