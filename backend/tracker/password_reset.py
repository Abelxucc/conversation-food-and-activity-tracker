"""Password recovery using Django tokens and the configured email backend."""

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import PasswordResetForm, SetPasswordForm
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils.http import urlsafe_base64_decode
from rest_framework import serializers
from rest_framework.decorators import (
    api_view, authentication_classes, parser_classes, permission_classes,
    throttle_classes,
)
from rest_framework.parsers import JSONParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle


class PasswordResetThrottle(AnonRateThrottle):
    scope = "password_reset"
    rate = "5/min"


class ResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class ResetConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField(max_length=128)
    token = serializers.CharField(max_length=128)
    new_password = serializers.CharField(trim_whitespace=False, max_length=4096)
    confirm_password = serializers.CharField(trim_whitespace=False, max_length=4096)


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
@throttle_classes([PasswordResetThrottle])
def request_password_reset(request):
    serializer = ResetRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    form = PasswordResetForm(serializer.validated_data)
    if form.is_valid():
        # The link origin comes from trusted settings, never the request Host.
        # In local development the console backend prints the email; it does
        # not send anything to an external email provider.
        form.save(
            domain_override="localhost",
            from_email=settings.DEFAULT_FROM_EMAIL,
            subject_template_name="tracker/password_reset_subject.txt",
            email_template_name="tracker/password_reset_email.txt",
            extra_email_context={
                "reset_frontend_url": settings.PASSWORD_RESET_FRONTEND_URL.rstrip("/"),
            },
        )
    # Do not reveal whether an address belongs to an account, or return a token.
    return Response({
        "detail": "If an eligible account matches that email, a reset link has been prepared.",
    })


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
@throttle_classes([PasswordResetThrottle])
def confirm_password_reset(request):
    serializer = ResetConfirmSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data
    user_model = get_user_model()
    invalid_link = {"detail": "This reset link is invalid or has expired. Request a new link."}

    with transaction.atomic():
        try:
            user_id = urlsafe_base64_decode(data["uid"]).decode()
            user = user_model.objects.select_for_update().get(pk=user_id)
        except (ValueError, TypeError, OverflowError, UnicodeError, ValidationError, user_model.DoesNotExist):
            return Response(invalid_link, status=400)
        if not user.is_active or not user.has_usable_password() or not default_token_generator.check_token(user, data["token"]):
            return Response(invalid_link, status=400)
        form = SetPasswordForm(user, {
            "new_password1": data["new_password"],
            "new_password2": data["confirm_password"],
        })
        if not form.is_valid():
            return Response({"errors": dict(form.errors)}, status=400)
        # Saving the hashed password also invalidates this token and old
        # Django sessions. Resetting a password does not log the user in.
        form.save()

    return Response({"detail": "Your password has been reset. You can now return to log in."})
