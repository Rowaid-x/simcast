"""Management command to set up Celery Beat periodic tasks."""
from django.core.management.base import BaseCommand
from django_celery_beat.models import PeriodicTask, IntervalSchedule


class Command(BaseCommand):
    help = 'Set up Celery Beat periodic tasks for Whisper'

    def handle(self, *args, **options):
        # Create or get a 60-second interval schedule
        schedule, created = IntervalSchedule.objects.get_or_create(
            every=60,
            period=IntervalSchedule.SECONDS,
        )

        # Create or update the auto-delete task
        task, task_created = PeriodicTask.objects.update_or_create(
            name='Auto-delete expired messages',
            defaults={
                'interval': schedule,
                'task': 'messages.auto_delete_expired',
                'enabled': True,
            },
        )

        if task_created:
            self.stdout.write(self.style.SUCCESS(
                'Created periodic task: Auto-delete expired messages (every 60s)'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                'Updated periodic task: Auto-delete expired messages (every 60s)'
            ))
