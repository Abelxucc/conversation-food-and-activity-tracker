from django.http import JsonResponse
from django.views.decorators.http import require_GET
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.generics import ListCreateAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import ActivityRecord, FoodEntry, FoodRecord
from .serializers import ActivityRecordSerializer, FoodEntrySerializer, FoodRecordSerializer


@require_GET
def health(request):
    return JsonResponse({"status": "ok", "service": "TrackTalk API"})


class OwnedRecords:
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class OwnedFoodRecords(OwnedRecords):
    serializer_class = FoodRecordSerializer

    def get_queryset(self):
        return FoodRecord.objects.filter(user=self.request.user).prefetch_related("items")


class FoodRecords(OwnedFoodRecords, ListCreateAPIView):
    pass


class FoodRecordDetail(OwnedFoodRecords, RetrieveUpdateDestroyAPIView):
    pass


class OwnedActivityRecords(OwnedRecords):
    serializer_class = ActivityRecordSerializer

    def get_queryset(self):
        return ActivityRecord.objects.filter(user=self.request.user)


class ActivityRecords(OwnedActivityRecords, ListCreateAPIView):
    pass


class ActivityRecordDetail(OwnedActivityRecords, RetrieveUpdateDestroyAPIView):
    pass


@api_view(["GET"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def food_entries(request):
    """Legacy read endpoint; unowned development data is never exposed."""
    entries = FoodEntry.objects.filter(record__user=request.user).order_by("-eaten_at", "-id")
    return Response({"entries": FoodEntrySerializer(entries, many=True).data})
