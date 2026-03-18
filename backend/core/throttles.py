"""Custom throttle classes for rate limiting specific endpoints."""
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class LoginRateThrottle(AnonRateThrottle):
    """5 attempts per minute per IP for login."""
    scope = 'login'


class RegisterRateThrottle(AnonRateThrottle):
    """3 attempts per hour per IP for registration."""
    scope = 'register'


class MessageRateThrottle(UserRateThrottle):
    """30 messages per minute per user."""
    scope = 'message'


class UploadRateThrottle(UserRateThrottle):
    """10 uploads per minute per user."""
    scope = 'upload'
