from django.http import JsonResponse
from django.views.decorators.http import require_GET
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import FoodEntry
from .serializers import FoodEntrySerializer


@require_GET
def health(request):
    return JsonResponse({
        "status": "ok",
        "service": "TrackTalk API",
    })


@api_view(["GET", "POST"])
def food_entries(request):
    if request.method == "GET":
        entries = FoodEntry.objects.all()
        serializer = FoodEntrySerializer(entries, many=True)
        return Response({"entries": serializer.data})

    serializer = FoodEntrySerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    serializer.save()

    return Response(
        serializer.data,
        status=status.HTTP_201_CREATED,
    )