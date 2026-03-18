"""URL patterns for messages and file uploads."""
from django.urls import path
from . import views

urlpatterns = [
    path(
        'conversations/<uuid:conversation_id>/messages/',
        views.MessageListCreateView.as_view(),
        name='message_list_create',
    ),
    path('messages/<uuid:pk>/', views.MessageDeleteView.as_view(), name='message_delete'),
    path('messages/<uuid:pk>/read/', views.MessageReadView.as_view(), name='message_read'),
    path('upload/', views.FileUploadView.as_view(), name='file_upload'),
]
