from django.db import models


class FoodEntry(models.Model):
    name = models.CharField(max_length=200)
    quantity = models.DecimalField(max_digits=8, decimal_places=2)
    unit = models.CharField(max_length=30)
    eaten_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-eaten_at", "-id"]

    def __str__(self):
        return f"{self.name}: {self.quantity} {self.unit}"