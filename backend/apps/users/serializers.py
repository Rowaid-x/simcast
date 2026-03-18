"""Serializers for user authentication and profile management."""
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    """Serializer for user registration."""
    password = serializers.CharField(write_only=True, min_length=8, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['id', 'email', 'password', 'password_confirm', 'display_name']
        read_only_fields = ['id']

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match.'})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(
            email=validated_data['email'],
            password=validated_data['password'],
            display_name=validated_data['display_name'],
        )
        return user


class LoginSerializer(serializers.Serializer):
    """Serializer for user login."""
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class ChangePasswordSerializer(serializers.Serializer):
    """Serializer for password change."""
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, min_length=8, validators=[validate_password])

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Current password is incorrect.')
        return value


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for user profile (read/update)."""

    class Meta:
        model = User
        fields = [
            'id', 'email', 'display_name', 'avatar_url', 'bio',
            'is_online', 'last_seen', 'created_at',
        ]
        read_only_fields = ['id', 'email', 'is_online', 'last_seen', 'created_at']


class UserSearchSerializer(serializers.ModelSerializer):
    """Minimal user serializer for search results."""

    class Meta:
        model = User
        fields = ['id', 'email', 'display_name', 'avatar_url', 'is_online', 'last_seen']
        read_only_fields = fields


class DeviceTokenSerializer(serializers.Serializer):
    """Serializer for registering FCM device tokens."""
    device_token = serializers.CharField(max_length=500)
