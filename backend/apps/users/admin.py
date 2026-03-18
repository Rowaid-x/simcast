"""Admin configuration for User model."""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['email', 'display_name', 'is_online', 'last_seen', 'is_active']
    list_filter = ['is_online', 'is_active', 'is_staff']
    search_fields = ['email', 'display_name']
    ordering = ['-created_at']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Profile', {'fields': ('display_name', 'avatar_url', 'bio', 'is_online', 'last_seen', 'device_token')}),
    )
