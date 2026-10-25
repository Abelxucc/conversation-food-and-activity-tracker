from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models.functions import Lower


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

class AccountProfile(models.Model):
    """Registration details linked to the existing Django authentication user."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="account_profile",
    )
    email = models.EmailField(max_length=254)
    phone_number = models.CharField(max_length=16)

    class Gender(models.TextChoices):
        MALE = "male", "Male"
        FEMALE = "female", "Female"
        NON_BINARY = "non_binary", "Non-binary"
        PREFER_NOT_TO_SAY = "prefer_not_to_say", "Prefer not to say"

    gender = models.CharField(max_length=20, choices=Gender.choices, blank=True, default="")
    height_cm = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(30), MaxValueValidator(300)])
    weight_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(500)])
    age = models.PositiveSmallIntegerField(null=True, blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(120)])

    class Meta:
        constraints = [
            models.UniqueConstraint(Lower("email"), name="unique_account_email_ci"),
        ]

    def __str__(self):
        return self.email

class PasswordResetRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        COMPLETED = "completed", "Completed"
        CLOSED = "closed", "Closed without reset"

    email = models.EmailField(max_length=254)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.PENDING, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    account = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="password_reset_requests")
    handled_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="handled_password_reset_requests")
    handled_at = models.DateTimeField(null=True, blank=True)
    identity_verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="verified_password_reset_requests")
    identity_verified_at = models.DateTimeField(null=True, blank=True)
    admin_notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.UniqueConstraint(fields=["email"], condition=models.Q(status="pending"),
                name="unique_pending_reset_email"),
        ]

    def __str__(self):
        return f"{self.email} — {self.get_status_display()}"
