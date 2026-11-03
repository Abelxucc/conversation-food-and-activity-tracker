from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from .models import FoodEntry, FoodRecord


class SignOutTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = get_user_model().objects.create_user(
            username="owner", email="owner@example.com", password="Example-pass-123")
        self.token = Token.objects.create(user=self.user)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")
        self.url = reverse("sign_out")

    def test_sign_out_revokes_the_token_without_deleting_food_or_other_accounts(self):
        record = FoodRecord.objects.create(
            user=self.user, meal_type="breakfast", eaten_at=timezone.now())
        FoodEntry.objects.create(record=record, name="Porridge", eaten_at=record.eaten_at)
        other = get_user_model().objects.create_user(username="other")
        other_token = Token.objects.create(user=other)
        response = self.client.post(self.url)
        self.assertEqual(response.status_code, 204)
        self.assertFalse(Token.objects.filter(key=self.token.key).exists())
        self.assertEqual(self.client.get(reverse("food_records")).status_code, 401)
        self.assertEqual(self.client.post(self.url).status_code, 401)
        self.assertTrue(Token.objects.filter(key=other_token.key).exists())
        self.assertTrue(FoodRecord.objects.filter(pk=record.pk).exists())
        self.assertEqual(FoodEntry.objects.filter(record=record).count(), 1)

    def test_sign_in_after_sign_out_issues_a_new_working_token(self):
        self.assertEqual(self.client.post(self.url).status_code, 204)
        response = self.client.post(reverse("sign_in"), {
            "email": "owner@example.com", "password": "Example-pass-123",
        }, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertNotEqual(response.data["token"], self.token.key)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {response.data["token"]}')
        self.assertEqual(self.client.get(reverse("food_records")).status_code, 200)

    def test_sign_out_requires_authentication_and_post(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)
        self.assertTrue(Token.objects.filter(key=self.token.key).exists())
        anonymous = APIClient()
        self.assertEqual(anonymous.post(self.url).status_code, 401)
        anonymous.credentials(HTTP_AUTHORIZATION="Token invalid")
        self.assertEqual(anonymous.post(self.url).status_code, 401)
        self.assertTrue(Token.objects.filter(key=self.token.key).exists())
