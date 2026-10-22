"""Create email/password accounts and store their required phone number."""

import re
import uuid

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from rest_framework import serializers, status
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    parser_classes,
    permission_classes,
    throttle_classes,
)
from rest_framework.parsers import JSONParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from .models import AccountProfile


class RegistrationThrottle(AnonRateThrottle):
    scope = "account_registration"
    rate = "5/min"


class RegistrationSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    confirm_email = serializers.EmailField(max_length=254, write_only=True)
    password = serializers.CharField(
        write_only=True, trim_whitespace=False, max_length=4096
    )
    phone_number = serializers.CharField(max_length=40)

    def validate_phone_number(self, value):
        # Accept readable formatting, but store only a leading + and digits.
        if not re.fullmatch(r"[+0-9 ()\-.]+", value):
            raise serializers.ValidationError("Enter a valid phone number.")
        normalized = re.sub(r"[ ()\-.]", "", value)
        if not re.fullmatch(r"\+?[0-9]{7,15}", normalized):
            raise serializers.ValidationError("Use 7 to 15 digits, with an optional country code.")
        return normalized

    def validate(self, attrs):
        email = attrs["email"].strip().lower()
        if email != attrs["confirm_email"].strip().lower():
            raise serializers.ValidationError({"confirm_email": "The email addresses do not match."})
        user_model = get_user_model()
        # Legacy Django users (including admin/demo accounts) may have no profile.
        if user_model.objects.filter(email__iexact=email).exists() or AccountProfile.objects.filter(email=email).exists():
            raise serializers.ValidationError({"email": "An account with this email address already exists."})
        try:
            validate_password(attrs["password"], user=user_model(email=email))
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": list(error.messages)}) from error
        attrs["email"] = email
        return attrs

    def create(self, validated_data):
        try:
            with transaction.atomic():
                # No extra username field is required in the registration UI.
                # create_user hashes the password using Django's password hasher.
                user = get_user_model().objects.create_user(
                    username=uuid.uuid4().hex,
                    email=validated_data["email"],
                    password=validated_data["password"],
                )
                AccountProfile.objects.create(
                    user=user,
                    email=validated_data["email"],
                    phone_number=validated_data["phone_number"],
                )
                return user
        except IntegrityError as error:
            # The unique normalized email also protects concurrent submissions.
            # Roll back both records rather than leaving an orphaned auth user.
            raise serializers.ValidationError({
                "email": "An account with this email address already exists.",
            }) from error


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
@throttle_classes([RegistrationThrottle])
def register_account(request):
    serializer = RegistrationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    return Response({
        "detail": "Your account has been created.",
        "email": user.email,
    }, status=status.HTTP_201_CREATED)
