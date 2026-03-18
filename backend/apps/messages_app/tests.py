"""Tests for message auto-deletion and encryption."""
import base64
import os
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone

from apps.conversations.models import Conversation, ConversationMember
from apps.messages_app.models import Message
from apps.messages_app.tasks import auto_delete_expired_messages
from core.encryption import encrypt_message, decrypt_message

User = get_user_model()

# Test encryption key (32 bytes base64 encoded)
TEST_ENCRYPTION_KEY = base64.b64encode(os.urandom(32)).decode()


@override_settings(MESSAGE_ENCRYPTION_KEY=TEST_ENCRYPTION_KEY)
class EncryptionTests(TestCase):
    """Test AES-256-GCM message encryption/decryption."""

    def test_encrypt_decrypt_roundtrip(self):
        """Verify that encrypting then decrypting returns the original text."""
        plaintext = "Hello, this is a secret message!"
        ciphertext, nonce = encrypt_message(plaintext)

        self.assertIsInstance(ciphertext, bytes)
        self.assertIsInstance(nonce, bytes)
        self.assertEqual(len(nonce), 12)
        self.assertNotEqual(ciphertext, plaintext.encode('utf-8'))

        decrypted = decrypt_message(ciphertext, nonce)
        self.assertEqual(decrypted, plaintext)

    def test_different_nonces(self):
        """Verify that each encryption produces a unique nonce."""
        plaintext = "Same message"
        _, nonce1 = encrypt_message(plaintext)
        _, nonce2 = encrypt_message(plaintext)
        self.assertNotEqual(nonce1, nonce2)

    def test_empty_content_decrypt(self):
        """Verify that decrypting empty bytes returns empty string."""
        result = decrypt_message(b'', b'')
        self.assertEqual(result, '')

    def test_unicode_content(self):
        """Verify encryption works with unicode characters."""
        plaintext = "Hello 🌍 مرحبا 你好"
        ciphertext, nonce = encrypt_message(plaintext)
        decrypted = decrypt_message(ciphertext, nonce)
        self.assertEqual(decrypted, plaintext)


@override_settings(MESSAGE_ENCRYPTION_KEY=TEST_ENCRYPTION_KEY)
class AutoDeleteTests(TestCase):
    """Test the auto-delete system for expired messages."""

    def setUp(self):
        """Create test user, conversation, and messages."""
        self.user = User.objects.create_user(
            email='test@example.com',
            password='TestPassword123!',
            display_name='Test User',
        )
        self.conversation = Conversation.objects.create(
            type='direct',
            created_by=self.user,
            auto_delete_timer=3600,  # 1 hour
        )
        ConversationMember.objects.create(
            conversation=self.conversation,
            user=self.user,
            role='admin',
        )

    def _create_message(self, expires_at=None, content="Test message"):
        """Helper to create an encrypted test message."""
        ciphertext, nonce = encrypt_message(content)
        return Message.objects.create(
            conversation=self.conversation,
            sender=self.user,
            content_encrypted=ciphertext,
            content_nonce=nonce,
            message_type='text',
            expires_at=expires_at,
        )

    def test_expired_messages_are_deleted(self):
        """Verify that expired messages are soft-deleted and wiped."""
        expired_time = timezone.now() - timedelta(hours=2)
        msg = self._create_message(expires_at=expired_time)

        result = auto_delete_expired_messages()

        msg.refresh_from_db()
        self.assertTrue(msg.is_deleted)
        self.assertEqual(bytes(msg.content_encrypted), b'')
        self.assertEqual(bytes(msg.content_nonce), b'')
        self.assertIn('Deleted 1', result)

    def test_non_expired_messages_are_kept(self):
        """Verify that messages with future expiry are not deleted."""
        future_time = timezone.now() + timedelta(hours=2)
        msg = self._create_message(expires_at=future_time)

        auto_delete_expired_messages()

        msg.refresh_from_db()
        self.assertFalse(msg.is_deleted)
        self.assertNotEqual(bytes(msg.content_encrypted), b'')

    def test_messages_without_expiry_are_kept(self):
        """Verify that messages without expires_at are not deleted."""
        msg = self._create_message(expires_at=None)

        auto_delete_expired_messages()

        msg.refresh_from_db()
        self.assertFalse(msg.is_deleted)

    def test_already_deleted_messages_are_skipped(self):
        """Verify that already-deleted messages are not processed again."""
        expired_time = timezone.now() - timedelta(hours=2)
        msg = self._create_message(expires_at=expired_time)
        msg.is_deleted = True
        msg.save(update_fields=['is_deleted'])

        result = auto_delete_expired_messages()
        self.assertIn('No expired messages', result)

    def test_multiple_expired_messages(self):
        """Verify batch deletion of multiple expired messages."""
        expired_time = timezone.now() - timedelta(hours=1)
        for i in range(5):
            self._create_message(expires_at=expired_time, content=f"Message {i}")

        result = auto_delete_expired_messages()
        self.assertIn('Deleted 5', result)

        deleted_count = Message.objects.filter(
            conversation=self.conversation, is_deleted=True
        ).count()
        self.assertEqual(deleted_count, 5)
