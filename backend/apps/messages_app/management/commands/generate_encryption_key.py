"""Management command to generate a new AES-256 encryption key."""
import base64
import os

from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Generate a new 32-byte AES-256 encryption key (base64 encoded)'

    def handle(self, *args, **options):
        key = base64.b64encode(os.urandom(32)).decode()
        self.stdout.write(self.style.SUCCESS(
            f'\nGenerated MESSAGE_ENCRYPTION_KEY:\n\n  {key}\n\n'
            f'Add this to your .env file:\n  MESSAGE_ENCRYPTION_KEY={key}\n'
        ))
