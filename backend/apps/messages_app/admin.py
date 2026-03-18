"""Admin configuration for Message models."""
from django.contrib import admin
from .models import Message, MessageReadReceipt


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'sender', 'message_type', 'is_deleted', 'expires_at', 'created_at']
    list_filter = ['message_type', 'is_deleted']
    search_fields = ['id']
    readonly_fields = ['content_encrypted', 'content_nonce']


@admin.register(MessageReadReceipt)
class MessageReadReceiptAdmin(admin.ModelAdmin):
    list_display = ['message', 'user', 'read_at']
