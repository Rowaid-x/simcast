"""User profile and search URL patterns."""
from django.urls import path
from . import views

urlpatterns = [
    path('me/', views.UserProfileView.as_view(), name='user_profile'),
    path('search/', views.UserSearchView.as_view(), name='user_search'),
    path('me/device-token/', views.DeviceTokenView.as_view(), name='device_token'),
]
