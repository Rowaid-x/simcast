"""Custom User model with UUID primary key and security-focused fields."""
import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """
    Extended user model for Whisper.

    Uses UUID as primary key, email-based authentication,
    and includes profile fields for the chat application.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(max_length=255, unique=True)
    username = models.CharField(max_length=150, unique=True, blank=True)
    display_name = models.CharField(max_length=50)
    avatar_url = models.URLField(max_length=500, blank=True, null=True)
    bio = models.CharField(max_length=200, blank=True, default='')
    is_online = models.BooleanField(default=False)
    last_seen = models.DateTimeField(blank=True, null=True)
    device_token = models.CharField(max_length=500, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['display_name']

    class Meta:
        db_table = 'users'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.display_name} ({self.email})"

    def save(self, *args, **kwargs):
        """Auto-generate username from email if not set."""
        if not self.username:
            self.username = self.email.split('@')[0] + '_' + str(self.id)[:8]
        super().save(*args, **kwargs)
