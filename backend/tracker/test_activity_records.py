from datetime import datetime, timezone

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from .models import ActivityRecord


class ActivityRecordTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username="activity-owner")
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.create(user=self.user).key}")
        self.url = reverse("activity_records")
        self.draft = {
            "name": "Jogging",
            "duration_minutes": 30,
            "occurred_at": "2026-10-06T00:00:00+00:00",
        }

    def test_activity_can_be_created_without_a_time_edited_and_deleted(self):
        created = self.client.post(self.url, self.draft, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        self.assertFalse(created.data["time_specified"])
        self.assertEqual(self.client.get(self.url).data, [created.data])
        detail = reverse("activity_record_detail", args=[created.data["id"]])

        changed = self.client.put(detail, {
            **self.draft,
            "name": "Cycling",
            "duration_minutes": 45,
            "occurred_at": "2026-10-06T08:30:00+00:00",
            "time_specified": True,
        }, format="json")
        self.assertEqual(changed.status_code, 200, changed.data)
        saved = ActivityRecord.objects.get(pk=created.data["id"])
        self.assertEqual(saved.user, self.user)
        self.assertEqual(saved.name, "Cycling")
        self.assertEqual(saved.duration_minutes, 45)
        self.assertEqual(saved.occurred_at, datetime(2026, 10, 6, 8, 30, tzinfo=timezone.utc))
        self.assertTrue(saved.time_specified)
        self.assertEqual(self.client.delete(detail).status_code, 204)
        self.assertEqual(self.client.get(self.url).data, [])

    def test_other_accounts_cannot_read_or_change_activity_records(self):
        created = self.client.post(self.url, self.draft, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        detail = reverse("activity_record_detail", args=[created.data["id"]])
        other = get_user_model().objects.create_user(username="other-account")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.create(user=other).key}")
        self.assertEqual(self.client.get(self.url).data, [])
        self.assertEqual(self.client.get(detail).status_code, 404)
        self.assertEqual(self.client.put(detail, self.draft, format="json").status_code, 404)
        self.assertEqual(self.client.delete(detail).status_code, 404)
        self.assertEqual(ActivityRecord.objects.get().user, self.user)
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)
        self.assertEqual(self.client.post(self.url, self.draft, format="json").status_code, 401)

    def test_invalid_activity_details_do_not_save(self):
        invalid_values = [
            ("name", " "),
            ("name", "x" * 201),
            ("duration_minutes", 0),
            ("duration_minutes", -5),
            ("duration_minutes", 1.5),
            ("duration_minutes", 2147483648),
            ("occurred_at", "invalid date"),
        ]
        for field, value in invalid_values:
            with self.subTest(field=field, value=value):
                result = self.client.post(self.url, {**self.draft, field: value}, format="json")
                self.assertEqual(result.status_code, 400, result.data)
                self.assertIn(field, result.data)
        for field in self.draft:
            with self.subTest(missing=field):
                missing = {key: value for key, value in self.draft.items() if key != field}
                result = self.client.post(self.url, missing, format="json")
                self.assertEqual(result.status_code, 400, result.data)
                self.assertIn(field, result.data)
        self.assertFalse(ActivityRecord.objects.exists())
