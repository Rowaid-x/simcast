"""Celery configuration for the Whisper project."""
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'whisper.settings')

app = Celery('whisper')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
