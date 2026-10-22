"""Accept recovery requests for administrator review, without sending email."""

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

from .models import PasswordResetRequest


class PasswordResetThrottle(AnonRateThrottle):
    scope = "password_reset"
    rate = "5/min"


class ResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([JSONParser])
@throttle_classes([PasswordResetThrottle])
def request_password_reset(request):
    serializer = ResetRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"].strip().lower()
    PasswordResetRequest.objects.get_or_create(
        email=email,
        status=PasswordResetRequest.Status.PENDING,
    )
    # The same result is returned for every valid address. A request does not
    # prove identity, expose an account, change a password or send an email.
    return Response({
        "detail": "Your request has been submitted. Please contact your administrator to verify your identity and complete the reset.",
    }, status=status.HTTP_202_ACCEPTED)
