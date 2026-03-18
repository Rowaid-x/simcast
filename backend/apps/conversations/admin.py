"""Admin configuration for Conversation models."""
from django.contrib import admin
from .models import Conversation, ConversationMember


class ConversationMemberInline(admin.TabularInline):
    model = ConversationMember
    extra = 0


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'type', 'name', 'auto_delete_timer', 'created_at']
    list_filter = ['type', 'auto_delete_timer']
    inlines = [ConversationMemberInline]
