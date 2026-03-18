"""Views for message management and file uploads."""
import os
import uuid as uuid_lib
import mimetypes

from django.conf import settings
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.conversations.models import Conversation, ConversationMember
from core.pagination import MessageCursorPagination
from core.throttles import MessageRateThrottle, UploadRateThrottle
from .models import Message, MessageReadReceipt
from .serializers import MessageListSerializer, CreateMessageSerializer


ALLOWED_MIME_TYPES = {
    'image/jpeg', 'image/png', 'image/gif', 'image/webp',
    'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/aac', 'audio/mp4',
    'application/pdf', 'application/zip',
    'text/plain', 'text/csv',
    'video/mp4', 'video/webm',
}
MAX_FILE_SIZE = 25 * 1024 * 1024  # 25MB


class MessageListCreateView(generics.ListCreateAPIView):
    """
    List messages in a conversation or send a new message.

    GET: Paginated, cursor-based (newest first).
    POST: Create a new encrypted message.
    """
    pagination_class = MessageCursorPagination

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateMessageSerializer
        return MessageListSerializer

    def get_throttles(self):
        if self.request.method == 'POST':
            return [MessageRateThrottle()]
        return []

    def get_queryset(self):
        conversation_id = self.kwargs['conversation_id']
        # Verify the user is a member
        if not ConversationMember.objects.filter(
            conversation_id=conversation_id, user=self.request.user
        ).exists():
            return Message.objects.none()

        return Message.objects.filter(
            conversation_id=conversation_id,
            is_deleted=False,
        ).select_related('sender', 'reply_to', 'reply_to__sender')

    def create(self, request, *args, **kwargs):
        conversation_id = self.kwargs['conversation_id']

        # Verify membership
        if not ConversationMember.objects.filter(
            conversation_id=conversation_id, user=request.user
        ).exists():
            return Response(
                {'error': {'code': 'forbidden', 'message': 'You are not a member of this conversation.'}},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = CreateMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = serializer.save(
            conversation=conversation,
            sender=request.user,
        )

        # Update conversation updated_at
        conversation.save(update_fields=['updated_at'])

        response_serializer = MessageListSerializer(message, context={'request': request})
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)


class MessageDeleteView(APIView):
    """Delete a single message (soft delete with content wiping)."""

    def delete(self, request, pk):
        try:
            message = Message.objects.get(pk=pk)
        except Message.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        # Only the sender can delete their message
        if message.sender != request.user:
            return Response(
                {'error': {'code': 'forbidden', 'message': 'You can only delete your own messages.'}},
                status=status.HTTP_403_FORBIDDEN,
            )

        message.is_deleted = True
        message.content_encrypted = b''
        message.content_nonce = b''
        message.file_url = None
        message.save(update_fields=['is_deleted', 'content_encrypted', 'content_nonce', 'file_url', 'updated_at'])

        return Response(status=status.HTTP_204_NO_CONTENT)


class MessageReadView(APIView):
    """Mark a message as read."""

    def post(self, request, pk):
        try:
            message = Message.objects.get(pk=pk)
        except Message.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        # Verify membership
        if not ConversationMember.objects.filter(
            conversation=message.conversation, user=request.user
        ).exists():
            return Response(status=status.HTTP_403_FORBIDDEN)

        MessageReadReceipt.objects.get_or_create(
            message=message,
            user=request.user,
            defaults={'read_at': timezone.now()},
        )

        return Response({'message': 'Marked as read.'})


class FileUploadView(APIView):
    """
    Upload a file with MIME type validation and size limits.

    Files are stored with randomized filenames to prevent enumeration.
    """
    parser_classes = [MultiPartParser]
    throttle_classes = [UploadRateThrottle]

    def post(self, request):
        file = request.FILES.get('file')
        if not file:
            return Response(
                {'error': {'code': 'bad_request', 'message': 'No file provided.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate file size
        if file.size > MAX_FILE_SIZE:
            return Response(
                {'error': {'code': 'bad_request', 'message': f'File size exceeds {MAX_FILE_SIZE // (1024*1024)}MB limit.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate MIME type
        mime_type = file.content_type or mimetypes.guess_type(file.name)[0]
        if mime_type not in ALLOWED_MIME_TYPES:
            return Response(
                {'error': {'code': 'bad_request', 'message': f'File type "{mime_type}" is not allowed.'}},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Generate randomized filename
        ext = os.path.splitext(file.name)[1].lower()
        random_name = f"{uuid_lib.uuid4().hex}{ext}"
        upload_dir = os.path.join(settings.MEDIA_ROOT, 'uploads', timezone.now().strftime('%Y/%m'))
        os.makedirs(upload_dir, exist_ok=True)
        file_path = os.path.join(upload_dir, random_name)

        # Write file to disk
        with open(file_path, 'wb+') as dest:
            for chunk in file.chunks():
                dest.write(chunk)

        # Build the URL
        relative_path = os.path.relpath(file_path, settings.MEDIA_ROOT)
        file_url = f"{request.scheme}://{request.get_host()}{settings.MEDIA_URL}{relative_path.replace(os.sep, '/')}"

        return Response({
            'file_url': file_url,
            'file_name': file.name,
            'file_size': file.size,
            'mime_type': mime_type,
        }, status=status.HTTP_201_CREATED)
