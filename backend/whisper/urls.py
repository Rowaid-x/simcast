"""URL configuration for Whisper project."""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.users.urls_auth')),
    path('api/v1/users/', include('apps.users.urls_users')),
    path('api/v1/conversations/', include('apps.conversations.urls')),
    path('api/v1/', include('apps.messages_app.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
