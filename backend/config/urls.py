from django.contrib import admin
from django.urls import path

from tracker.views import health, food_entries
from tracker.password_reset import request_password_reset, confirm_password_reset

urlpatterns = [
    path("api/auth/password-reset/", request_password_reset, name="password_reset_request"),
    path("api/auth/password-reset/confirm/", confirm_password_reset, name="password_reset_confirm"),
    path("admin/", admin.site.urls),
    path("api/health/", health, name="health"),
    path("api/food-entries/", food_entries, name="food_entries"),
]