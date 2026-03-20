"""Views for conversation management."""
from datetime import timedelta

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model
from django.db.models import Q, Max
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from core.pagination import ConversationPagination
from .models import Conversation, ConversationMember
from .serializers import (
    ConversationListSerializer,
    ConversationDetailSerializer,
    CreateDirectConversationSerializer,
    CreateGroupConversationSerializer,
    UpdateConversationSerializer,
    AddMembersSerializer,
)

User = get_user_model()


class ConversationListCreateView(generics.ListCreateAPIView):
    """
    List the user's conversations or create a new one.

    POST body for direct: { "type": "direct", "user_id": "uuid" }
    POST body for group:  { "type": "group", "name": "...", "member_ids": ["uuid", ...] }
    """
    pagination_class = ConversationPagination

    def get_serializer_class(self):
        if self.request.method == 'POST':
            conv_type = self.request.data.get('type', 'direct')
            if conv_type == 'group':
                return CreateGroupConversationSerializer
            return CreateDirectConversationSerializer
        return ConversationListSerializer

    def get_queryset(self):
        return Conversation.objects.filter(
            memberships__user=self.request.user
        ).annotate(
            last_message_at=Max('messages__created_at')
        ).order_by('-last_message_at', '-updated_at').distinct()

    def create(self, request, *args, **kwargs):
        conv_type = request.data.get('type', 'direct')

        if conv_type == 'direct':
            return self._create_direct(request)
        elif conv_type == 'group':
            return self._create_group(request)
        else:
            return Response(
                {'error': {'code': 'bad_request', 'message': 'Invalid conversation type.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

    def _create_direct(self, request):
        """Create or retrieve a direct conversation between two users."""
        serializer = CreateDirectConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        other_user_id = serializer.validated_data['user_id']

        if str(other_user_id) == str(request.user.id):
            return Response(
                {'error': {'code': 'bad_request', 'message': 'Cannot start a conversation with yourself.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check if direct conversation already exists
        existing = Conversation.objects.filter(
            type='direct',
            memberships__user=request.user,
        ).filter(
            memberships__user_id=other_user_id,
        ).first()

        if existing:
            return Response(
                ConversationDetailSerializer(existing, context={'request': request}).data,
                status=status.HTTP_200_OK,
            )

        # Create new direct conversation
        conversation = Conversation.objects.create(
            type='direct',
            created_by=request.user,
        )
        ConversationMember.objects.create(
            conversation=conversation, user=request.user, role='admin'
        )
        ConversationMember.objects.create(
            conversation=conversation, user_id=other_user_id, role='admin'
        )

        return Response(
            ConversationDetailSerializer(conversation, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    def _create_group(self, request):
        """Create a new group conversation."""
        serializer = CreateGroupConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        conversation = Conversation.objects.create(
            type='group',
            name=serializer.validated_data['name'],
            created_by=request.user,
        )
        # Add creator as admin
        ConversationMember.objects.create(
            conversation=conversation, user=request.user, role='admin'
        )
        # Add other members
        for uid in serializer.validated_data['member_ids']:
            if str(uid) != str(request.user.id):
                ConversationMember.objects.create(
                    conversation=conversation, user_id=uid, role='member'
                )

        return Response(
            ConversationDetailSerializer(conversation, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class ConversationDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Retrieve, update, or leave/delete a conversation.

    PATCH: Update name, avatar, auto_delete_timer.
    DELETE: Leave the conversation (or delete if last member).
    """
    serializer_class = ConversationDetailSerializer

    def get_queryset(self):
        return Conversation.objects.filter(memberships__user=self.request.user)

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UpdateConversationSerializer
        return ConversationDetailSerializer

    def perform_update(self, serializer):
        conversation = self.get_object()
        old_timer = conversation.auto_delete_timer
        instance = serializer.save()

        # If auto_delete_timer changed, recalculate expires_at for existing messages
        new_timer = instance.auto_delete_timer
        if old_timer != new_timer:
            self._recalculate_expires(instance, new_timer)
            self._broadcast_timer_update(instance, new_timer)

    def _broadcast_timer_update(self, conversation, new_timer):
        """Broadcast auto_delete_timer change to all members via WebSocket."""
        channel_layer = get_channel_layer()
        group_name = f'conversation_{conversation.id}'
        async_to_sync(channel_layer.group_send)(
            group_name,
            {
                'type': 'chat.timer_update',
                'conversation_id': str(conversation.id),
                'auto_delete_timer': new_timer,
            },
        )

    def _recalculate_expires(self, conversation, new_timer):
        """Recalculate expires_at for all non-deleted messages when timer changes."""
        from apps.messages_app.models import Message
        messages = Message.objects.filter(
            conversation=conversation,
            is_deleted=False,
        )
        if new_timer is None:
            messages.update(expires_at=None)
        else:
            for msg in messages:
                msg.expires_at = msg.created_at + timedelta(seconds=new_timer)
                msg.save(update_fields=['expires_at'])

    def destroy(self, request, *args, **kwargs):
        """Leave the conversation. Delete it if you're the last member."""
        conversation = self.get_object()
        membership = ConversationMember.objects.filter(
            conversation=conversation, user=request.user
        ).first()

        if not membership:
            return Response(status=status.HTTP_404_NOT_FOUND)

        membership.delete()

        # If no members left, delete the conversation
        if conversation.memberships.count() == 0:
            conversation.delete()

        return Response(status=status.HTTP_204_NO_CONTENT)


class ConversationMembersView(APIView):
    """Add members to a group conversation."""

    def post(self, request, pk):
        """Add members to the group."""
        try:
            conversation = Conversation.objects.get(pk=pk, type='group')
        except Conversation.DoesNotExist:
            return Response(
                {'error': {'code': 'not_found', 'message': 'Group conversation not found.'}},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Verify the requesting user is a member
        if not conversation.memberships.filter(user=request.user).exists():
            return Response(status=status.HTTP_403_FORBIDDEN)

        serializer = AddMembersSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        added = []
        for uid in serializer.validated_data['user_ids']:
            if not conversation.memberships.filter(user_id=uid).exists():
                ConversationMember.objects.create(
                    conversation=conversation, user_id=uid, role='member'
                )
                added.append(str(uid))

        return Response({'added': added}, status=status.HTTP_201_CREATED)


class ConversationRemoveMemberView(APIView):
    """Remove a member from a group conversation."""

    def delete(self, request, pk, user_id):
        try:
            conversation = Conversation.objects.get(pk=pk, type='group')
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        # Only admins can remove others; anyone can remove themselves
        requesting_membership = conversation.memberships.filter(user=request.user).first()
        if not requesting_membership:
            return Response(status=status.HTTP_403_FORBIDDEN)

        if str(user_id) != str(request.user.id) and requesting_membership.role != 'admin':
            return Response(
                {'error': {'code': 'forbidden', 'message': 'Only admins can remove members.'}},
                status=status.HTTP_403_FORBIDDEN,
            )

        target_membership = conversation.memberships.filter(user_id=user_id).first()
        if not target_membership:
            return Response(status=status.HTTP_404_NOT_FOUND)

        target_membership.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
