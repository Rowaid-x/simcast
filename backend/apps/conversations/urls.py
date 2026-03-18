"""URL patterns for conversations."""
from django.urls import path
from . import views

urlpatterns = [
    path('', views.ConversationListCreateView.as_view(), name='conversation_list_create'),
    path('<uuid:pk>/', views.ConversationDetailView.as_view(), name='conversation_detail'),
    path('<uuid:pk>/members/', views.ConversationMembersView.as_view(), name='conversation_members'),
    path('<uuid:pk>/members/<uuid:user_id>/', views.ConversationRemoveMemberView.as_view(), name='conversation_remove_member'),
]
