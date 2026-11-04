from django.db import transaction
from rest_framework import serializers

from .models import ActivityRecord, FoodEntry, FoodRecord


class FoodEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodEntry
        fields = ["id", "name", "quantity", "unit", "eaten_at", "created_at"]
        read_only_fields = ["id", "created_at", "eaten_at"]

    def validate_quantity(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError("Quantity must be greater than zero.")
        return value

    def validate(self, attrs):
        if not attrs.get("name"):
            raise serializers.ValidationError({"name": "Enter a food name."})
        quantity = attrs.get("quantity")
        unit = attrs.get("unit", "").strip()
        if (quantity is None) != (not unit):
            raise serializers.ValidationError(
                "Enter both quantity and unit, or leave both empty."
            )
        return attrs


class FoodRecordSerializer(serializers.ModelSerializer):
    items = FoodEntrySerializer(many=True, allow_empty=False, max_length=50)

    class Meta:
        model = FoodRecord
        fields = ["id", "meal_type", "eaten_at", "time_specified", "items", "created_at"]
        read_only_fields = ["id", "created_at"]

    @transaction.atomic
    def create(self, validated_data):
        items = validated_data.pop("items")
        record = FoodRecord.objects.create(**validated_data)
        self._save_items(record, items)
        return record

    @transaction.atomic
    def update(self, instance, validated_data):
        items = validated_data.pop("items", None)
        instance = super().update(instance, validated_data)
        if items is not None:
            instance.items.all().delete()
            self._save_items(instance, items)
        else:
            instance.items.update(eaten_at=instance.eaten_at)
        return instance

    @staticmethod
    def _save_items(record, items):
        FoodEntry.objects.bulk_create([
            FoodEntry(record=record, eaten_at=record.eaten_at, **item)
            for item in items
        ])


class ActivityRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = ActivityRecord
        fields = ["id", "name", "duration_minutes", "occurred_at", "time_specified", "created_at"]
        read_only_fields = ["id", "created_at"]
