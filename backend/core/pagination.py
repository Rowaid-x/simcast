"""Custom pagination classes for the Whisper API."""
from rest_framework.pagination import CursorPagination, LimitOffsetPagination


class MessageCursorPagination(CursorPagination):
    """
    Cursor-based pagination for messages.

    Orders by created_at descending so newest messages come first.
    Supports 'before' parameter for loading older messages.
    """
    page_size = 30
    ordering = '-created_at'
    cursor_query_param = 'cursor'


class ConversationPagination(LimitOffsetPagination):
    """Offset-based pagination for conversations list."""
    default_limit = 20
    max_limit = 50
