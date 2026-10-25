from django.contrib import admin
from django.urls import path

from tracker.registration import register_account, validate_registration

from tracker.views import health, food_entries
from tracker.password_reset import request_password_reset

urlpatterns = [
    path("api/auth/register/", register_account, name="register_account"),
    path("api/auth/register/validate/", validate_registration, name="validate_registration"),
    path("api/auth/password-reset/", request_password_reset, name="password_reset_request"),
    path("admin/", admin.site.urls),
    path("api/health/", health, name="health"),
    path("api/food-entries/", food_entries, name="food_entries"),
]
