from rest_framework import serializers

from .models import FoodEntry


class FoodEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodEntry
        fields = [
            "id",
            "name",
            "quantity",
            "unit",
            "eaten_at",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_quantity(self, value):
        if value <= 0:
            raise serializers.ValidationError(
                "Quantity must be greater than zero."
            )
        return value