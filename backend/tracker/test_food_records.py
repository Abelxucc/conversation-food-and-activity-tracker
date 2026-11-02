from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from .models import FoodEntry, FoodRecord


class FoodRecordTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = get_user_model().objects.create_user(
            username="owner", email="owner@example.com", password="Example-pass-123")
        self.other = get_user_model().objects.create_user(username="other", email="other@example.com")
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.create(user=self.user).key}")
        self.url = "/api/food-records/"
        self.payload = {"meal_type": "breakfast", "eaten_at": timezone.now().isoformat(), "items": [
            {"name": "Porridge", "quantity": "1.00", "unit": "bowl"},
            {"name": "Milk", "quantity": None, "unit": ""},
        ]}

    def create_record(self):
        response = self.client.post(self.url, self.payload, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def test_create_and_retrieve_with_a_new_authenticated_client(self):
        record = self.create_record()
        fresh = APIClient()
        fresh.credentials(HTTP_AUTHORIZATION=self.client._credentials["HTTP_AUTHORIZATION"])
        response = fresh.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data[0], record)
        self.assertIsNone(response.data[0]["items"][1]["quantity"])
        self.assertEqual(FoodRecord.objects.get().user, self.user)
        self.assertEqual(FoodEntry.objects.count(), 2)

    def test_update_replaces_items_and_changes_meal_and_time(self):
        record = self.create_record()
        replacement = {**self.payload, "meal_type": "lunch", "items": [
            {"name": "Sandwich", "quantity": "2", "unit": "slices"}]}
        response = self.client.put(f'{self.url}{record["id"]}/', replacement, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        saved = self.client.get(f'{self.url}{record["id"]}/').data
        self.assertEqual(saved["meal_type"], "lunch")
        self.assertEqual(saved["items"][0]["name"], "Sandwich")
        self.assertEqual(FoodEntry.objects.count(), 1)

    def test_patch_does_not_require_replacing_items(self):
        record = self.create_record()
        response = self.client.patch(f'{self.url}{record["id"]}/', {"meal_type": "snack"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["items"]), 2)

    def test_delete_cascades_to_all_food_items(self):
        record = self.create_record()
        self.assertEqual(self.client.delete(f'{self.url}{record["id"]}/').status_code, 204)
        self.assertEqual(FoodRecord.objects.count(), 0)
        self.assertEqual(FoodEntry.objects.count(), 0)
        self.assertEqual(self.client.get(self.url).data, [])

    def test_unspecified_snack_time_survives_reload_and_can_be_set_and_cleared(self):
        response = self.client.post(self.url,
            {**self.payload, "meal_type": "snack", "time_specified": False}, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        detail = f'{self.url}{response.data["id"]}/'
        self.assertFalse(self.client.get(self.url).data[0]["time_specified"])
        self.assertFalse(FoodRecord.objects.get().time_specified)
        self.assertEqual(len(response.data["items"]), 2)

        chosen_time = timezone.now().replace(hour=0, minute=0, second=0, microsecond=0)
        response = self.client.patch(detail,
            {"eaten_at": chosen_time.isoformat(), "time_specified": True}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(self.client.get(detail).data["time_specified"])
        self.assertEqual(FoodRecord.objects.get().eaten_at, chosen_time)

        response = self.client.patch(detail, {"time_specified": False}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(self.client.get(detail).data["time_specified"])
        self.assertEqual(FoodEntry.objects.count(), 2)

    def test_legacy_requests_keep_their_times_and_partial_edits_preserve_the_flag(self):
        record = self.create_record()
        self.assertTrue(record["time_specified"])
        detail = f'{self.url}{record["id"]}/'
        response = self.client.patch(detail, {"time_specified": False}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        response = self.client.put(detail, self.payload, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(response.data["time_specified"])
        self.assertFalse(FoodRecord.objects.get().time_specified)

    def test_other_account_cannot_list_read_edit_or_delete_record(self):
        record = self.create_record()
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(self.url).data, [])
        detail = f'{self.url}{record["id"]}/'
        for response in [self.client.get(detail),
                         self.client.put(detail, self.payload, format="json"),
                         self.client.delete(detail)]:
            self.assertEqual(response.status_code, 404)
        self.assertTrue(FoodRecord.objects.filter(pk=record["id"]).exists())
        self.assertEqual(self.client.get('/api/food-entries/').data, {"entries": []})

    def test_unauthenticated_access_is_rejected(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)
        self.assertEqual(self.client.post(self.url, self.payload, format="json").status_code, 401)
        self.assertEqual(self.client.get('/api/food-entries/').status_code, 401)

    def test_invalid_inputs_never_save_a_partial_meal(self):
        invalid = [[], [{"name": " "}], [{"name": "Milk", "quantity": 0, "unit": "g"}],
                   [{"name": "Milk", "quantity": -1, "unit": "g"}],
                   [{"name": "Milk", "quantity": 1}], [{"name": "Milk", "unit": "g"}],
                   [{"name": "Milk", "quantity": "0.001", "unit": "g"}]]
        for items in invalid:
            with self.subTest(items=items):
                response = self.client.post(self.url, {**self.payload, "items": items}, format="json")
                self.assertEqual(response.status_code, 400, response.data)
                self.assertEqual(FoodRecord.objects.count(), 0)
                self.assertEqual(FoodEntry.objects.count(), 0)

    def test_invalid_edit_keeps_original_record(self):
        record = self.create_record()
        response = self.client.put(f'{self.url}{record["id"]}/',
            {**self.payload, "items": [{"name": ""}]}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.client.get(f'{self.url}{record["id"]}/').data, record)

    def test_database_failure_rolls_back_parent_and_children(self):
        with patch('tracker.serializers.FoodEntry.objects.bulk_create', side_effect=RuntimeError):
            with self.assertRaises(RuntimeError):
                self.client.post(self.url, self.payload, format="json")
        self.assertEqual(FoodRecord.objects.count(), 0)
        self.assertEqual(FoodEntry.objects.count(), 0)

    def test_client_cannot_assign_a_different_owner(self):
        self.client.post(self.url, {**self.payload, "user": self.other.pk}, format="json")
        self.assertEqual(FoodRecord.objects.get().user, self.user)

    def test_unowned_legacy_entries_are_not_exposed(self):
        FoodEntry.objects.create(name="Legacy", quantity=1, unit="bowl", eaten_at=timezone.now())
        self.assertEqual(self.client.get('/api/food-entries/').data, {"entries": []})

    def test_real_login_uses_case_insensitive_email_and_password(self):
        anonymous = APIClient()
        response = anonymous.post('/api/auth/login/',
            {"email": "OWNER@example.com", "password": "Example-pass-123"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Token.objects.get(key=response.data["token"]).user, self.user)
        for email, password in [('owner@example.com', 'wrong'), ('missing@example.com', 'wrong')]:
            self.assertEqual(anonymous.post('/api/auth/login/',
                {"email": email, "password": password}, format="json").status_code, 400)
        self.user.is_active = False
        self.user.save()
        self.assertEqual(anonymous.post('/api/auth/login/',
            {"email": self.user.email, "password": "Example-pass-123"}, format="json").status_code, 400)
