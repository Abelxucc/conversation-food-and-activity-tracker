from django.contrib import admin
from django.urls import path

from tracker.food_ai import food_week, parse_food_record
from tracker.registration import register_account, validate_registration

from tracker.views import ActivityRecordDetail, ActivityRecords, FoodRecordDetail, FoodRecords, food_entries, health
from tracker.sign_in import sign_in, sign_out
from tracker.password_reset import request_password_reset

urlpatterns = [
    path("api/auth/login/", sign_in, name="sign_in"),
    path("api/auth/logout/", sign_out, name="sign_out"),
    path("api/auth/register/", register_account, name="register_account"),
    path("api/auth/register/validate/", validate_registration, name="validate_registration"),
    path("api/auth/password-reset/", request_password_reset, name="password_reset_request"),
    path("admin/", admin.site.urls),
    path("api/health/", health, name="health"),
    path("api/food-entries/", food_entries, name="food_entries"),
    path("api/food-records/", FoodRecords.as_view(), name="food_records"),
    path("api/food-records/parse/", parse_food_record, name="parse_food_record"),
    path("api/food-recommendations/", food_week, name="food_week"),
    path("api/food-records/<int:pk>/", FoodRecordDetail.as_view(), name="food_record_detail"),
    path("api/activity-records/", ActivityRecords.as_view(), name="activity_records"),
    path("api/activity-records/<int:pk>/", ActivityRecordDetail.as_view(), name="activity_record_detail"),
]
