"""
AES-256-GCM encryption utilities for message content.

All messages are encrypted at rest using AES-256-GCM with unique nonces.
The encryption key is loaded from the MESSAGE_ENCRYPTION_KEY environment variable.
"""
import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from django.conf import settings


def _get_key() -> bytes:
    """Retrieve and decode the AES-256 encryption key from settings."""
    key_b64 = settings.MESSAGE_ENCRYPTION_KEY
    if not key_b64:
        raise ValueError(
            "MESSAGE_ENCRYPTION_KEY is not set. "
            "Generate a 32-byte key with: python -c \"import os,base64; print(base64.b64encode(os.urandom(32)).decode())\""
        )
    key = base64.b64decode(key_b64)
    if len(key) != 32:
        raise ValueError("MESSAGE_ENCRYPTION_KEY must be exactly 32 bytes (256 bits) when decoded.")
    return key


def encrypt_message(plaintext: str) -> tuple[bytes, bytes]:
    """
    Encrypt a plaintext message using AES-256-GCM.

    Args:
        plaintext: The message content to encrypt.

    Returns:
        A tuple of (ciphertext, nonce) as bytes.
    """
    key = _get_key()
    nonce = os.urandom(12)  # 96-bit nonce for GCM
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode('utf-8'), None)
    return ciphertext, nonce


def decrypt_message(ciphertext: bytes, nonce: bytes) -> str:
    """
    Decrypt an AES-256-GCM encrypted message.

    Args:
        ciphertext: The encrypted message bytes.
        nonce: The 12-byte nonce used during encryption.

    Returns:
        The decrypted plaintext string.
    """
    if not ciphertext or not nonce:
        return ''
    key = _get_key()
    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext, None)
    return plaintext.decode('utf-8')
