from datetime import datetime, timezone
from unittest.mock import patch
from urllib.error import HTTPError

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from .models import FoodEntry, FoodRecord


class FoodAITests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.user = get_user_model().objects.create_user(username="tester")
        self.client.force_authenticate(self.user)
        self.parse_url = "/api/food-records/parse/"
        self.week_url = "/api/food-recommendations/?date=2026-07-08"
        self.payload = {"text": "Porridge with milk for breakfast", "reference_date": "2026-07-08"}

    def test_endpoints_require_login(self):
        anonymous = APIClient()
        self.assertEqual(anonymous.post(self.parse_url, self.payload, format="json").status_code, 401)
        self.assertEqual(anonymous.get(self.week_url).status_code, 401)

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_draft_leaves_missing_time_and_amount_empty_without_saving(self, ask):
        ask.return_value = {
            "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
            "items": [
                {"name": "Porridge", "quantity": 1, "unit": "bowl"},
                {"name": "Milk", "quantity": None, "unit": ""},
            ],
        }
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.data["date"], "2026-07-08")
        self.assertIsNone(result.data["time"])
        self.assertIsNone(result.data["items"][1]["quantity"])
        self.assertFalse(FoodRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_explicit_portion_is_recovered_if_model_omits_it(self, ask):
        for text, name, quantity, unit in [
            ("I had a bowl of porridge with milk for breakfast", "porridge", "1.00", "bowl"),
            ("For breakfast, I ate two slices of toast with milk", "toast", "2.00", "slices"),
            ("I had half a bowl of porridge with milk", "porridge", "0.50", "bowl"),
        ]:
            with self.subTest(text=text):
                ask.return_value = {
                    "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
                    "items": [
                        {"name": name, "quantity": None, "unit": ""},
                        {"name": "milk", "quantity": None, "unit": ""},
                    ],
                }
                result = self.client.post(self.parse_url, {**self.payload, "text": text}, format="json")
                self.assertEqual(result.status_code, 200, result.data)
                food, milk = result.data["items"]
                self.assertEqual((food["quantity"], food["unit"]), (quantity, unit))
                self.assertEqual((milk["quantity"], milk["unit"]), (None, ""))
        self.assertFalse(FoodRecord.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_invalid_model_payload_cannot_be_saved(self, ask):
        ask.return_value = {
            "status": "draft", "meal_type": "breakfast", "date": None, "time": None,
            "items": [{"name": "Porridge", "quantity": -1, "unit": "bowl"}],
        }
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 400, result.data)
        self.assertFalse(FoodEntry.objects.exists())

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai.urlopen")
    def test_openai_authentication_failure_reports_server_key_problem(self, request):
        request.side_effect = HTTPError(
            "https://api.openai.com/v1/responses", 401, "Unauthorized", None, None,
        )
        result = self.client.post(self.parse_url, self.payload, format="json")
        self.assertEqual(result.status_code, 503, result.data)
        self.assertIn("Check the API key", result.data["detail"])
        self.assertFalse(FoodRecord.objects.exists())

    def _record(self, user, timestamp, name):
        record = FoodRecord.objects.create(user=user, eaten_at=timestamp, meal_type="dinner")
        FoodEntry.objects.create(record=record, eaten_at=timestamp, name=name)

    @patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"})
    @patch("tracker.food_ai._ask")
    def test_week_uses_owned_uk_week_and_caches_grounded_tip(self, ask):
        other = get_user_model().objects.create_user(username="other")
        in_week = datetime(2026, 7, 5, 23, 30, tzinfo=timezone.utc)
        self._record(self.user, in_week, "Chicken")
        self._record(self.user, datetime(2026, 7, 5, 22, 59, tzinfo=timezone.utc), "Apple")
        self._record(other, in_week, "Chickpeas")
        ask.return_value = {"tip_id": "pulses_soup"}
        result = self.client.get(self.week_url)
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result.data["days_logged"], 1)
        groups = {group["label"]: group["foods"] for group in result.data["groups"]}
        self.assertEqual(groups["Protein foods"], ["Chicken"])
        self.assertEqual(groups["Fruit & vegetables"], [])
        self.assertIn("lentils", result.data["recommendation"]["body"])
        self.assertEqual(self.client.get(self.week_url).data, result.data)
        ask.assert_called_once()

    @patch.dict("os.environ", {"OPENAI_API_KEY": ""})
    def test_week_with_logs_has_guide_tip_even_without_a_key(self):
        self._record(self.user, datetime(2026, 7, 8, 12, tzinfo=timezone.utc), "Chicken")
        week = self.client.get(self.week_url)
        self.assertEqual(week.status_code, 200)
        self.assertIn("nhs.uk", week.data["recommendation"]["source_url"])
        self.assertEqual(self.client.post(self.parse_url, self.payload, format="json").status_code, 503)
