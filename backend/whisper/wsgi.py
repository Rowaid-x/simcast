"""WSGI config for Whisper project."""
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'whisper.settings')
application = get_wsgi_application()
