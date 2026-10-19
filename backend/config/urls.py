from django.contrib import admin
from django.urls import path

from tracker.views import health, food_entries

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", health, name="health"),
    path("api/food-entries/", food_entries, name="food_entries"),
]