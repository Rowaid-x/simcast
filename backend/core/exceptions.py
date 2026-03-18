"""Custom exception handler for consistent API error responses."""
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


def custom_exception_handler(exc, context):
    """
    Custom exception handler that wraps all errors in a consistent format.

    Response format:
    {
        "error": {
            "code": "error_code",
            "message": "Human-readable message",
            "details": { ... }  // optional
        }
    }
    """
    response = exception_handler(exc, context)

    if response is not None:
        error_data = {
            'error': {
                'code': _get_error_code(response.status_code),
                'message': _get_error_message(response.data),
                'details': response.data if isinstance(response.data, dict) else {'detail': response.data},
            }
        }
        response.data = error_data

    return response


def _get_error_code(status_code: int) -> str:
    """Map HTTP status codes to error code strings."""
    codes = {
        400: 'bad_request',
        401: 'unauthorized',
        403: 'forbidden',
        404: 'not_found',
        405: 'method_not_allowed',
        429: 'rate_limited',
        500: 'internal_error',
    }
    return codes.get(status_code, 'unknown_error')


def _get_error_message(data) -> str:
    """Extract a human-readable error message from response data."""
    if isinstance(data, dict):
        if 'detail' in data:
            return str(data['detail'])
        # Return the first error message found
        for key, value in data.items():
            if isinstance(value, list):
                return f"{key}: {value[0]}"
            return f"{key}: {value}"
    if isinstance(data, list):
        return str(data[0])
    return str(data)
