import json
from unittest.mock import patch

from django.contrib.auth import authenticate, get_user_model
from django.core import mail
from django.core.cache import cache
from django.db import IntegrityError
from django.test import TestCase, override_settings
from django.urls import reverse

from .models import AccountProfile, PasswordResetRequest


class RegistrationTests(TestCase):
    def setUp(self):
        cache.clear()
        self.url = reverse("register_account")
        self.data = {
            "email": "Person@Example.com",
            "confirm_email": "person@example.com",
            "password": "River-walk-739!",
            "phone_number": "+44 7700 900123",
        }

    def post(self, data=None):
        return self.client.post(self.url, json.dumps(self.data if data is None else data), content_type="application/json")

    def test_registration_persists_account_phone_and_hashed_password(self):
        response = self.post()
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["email"], "person@example.com")
        self.assertNotIn("password", response.json())
        user = get_user_model().objects.get(email="person@example.com")
        profile = AccountProfile.objects.get(user=user)
        self.assertEqual(profile.email, user.email)
        self.assertEqual(profile.phone_number, "+447700900123")
        self.assertTrue(user.check_password(self.data["password"]))
        self.assertNotEqual(user.password, self.data["password"])
        self.assertEqual(authenticate(username=user.username, password=self.data["password"]), user)
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)
        self.assertNotIn("_auth_user_id", self.client.session)

    def test_confirm_email_is_required_and_must_match(self):
        self.data["confirm_email"] = "other@example.com"
        self.assertEqual(self.post().status_code, 400)
        del self.data["confirm_email"]
        self.assertEqual(self.post().status_code, 400)
        self.assertEqual(get_user_model().objects.count(), 0)
        self.assertEqual(AccountProfile.objects.count(), 0)

    def test_password_policy_and_required_phone_are_checked_on_server(self):
        self.data["password"] = "123"
        self.assertEqual(self.post().status_code, 400)
        self.data["password"] = "River-walk-739!"
        self.data["phone_number"] = ""
        self.assertEqual(self.post().status_code, 400)
        self.assertEqual(get_user_model().objects.count(), 0)

    def test_invalid_email_and_phone_are_rejected(self):
        self.data["email"] = self.data["confirm_email"] = "not-an-email"
        self.assertEqual(self.post().status_code, 400)
        self.data["email"] = self.data["confirm_email"] = "person@example.com"
        self.data["phone_number"] = "call-me-1234567"
        self.assertEqual(self.post().status_code, 400)
        self.data["phone_number"] = "+1234567890123456"
        self.assertEqual(self.post().status_code, 400)
        self.assertEqual(AccountProfile.objects.count(), 0)

    def test_case_insensitive_duplicate_cannot_change_existing_account(self):
        self.assertEqual(self.post().status_code, 201)
        self.data["email"] = self.data["confirm_email"] = "PERSON@EXAMPLE.COM"
        self.data["password"] = "Another-river-91!"
        self.data["phone_number"] = "+447700900456"
        self.assertEqual(self.post().status_code, 400)
        user = get_user_model().objects.get(email="person@example.com")
        self.assertTrue(user.check_password("River-walk-739!"))
        self.assertEqual(user.account_profile.phone_number, "+447700900123")
        self.assertEqual(get_user_model().objects.count(), 1)

    def test_legacy_user_email_cannot_be_registered_again(self):
        get_user_model().objects.create_user(username="legacy", email="PERSON@example.com", password="Old-password-71!")
        self.assertEqual(self.post().status_code, 400)
        self.assertEqual(get_user_model().objects.count(), 1)
        self.assertEqual(AccountProfile.objects.count(), 0)

    def test_atomic_creation_does_not_leave_an_orphaned_user(self):
        with patch("tracker.registration.AccountProfile.objects.create", side_effect=IntegrityError("duplicate")):
            response = self.post()
        self.assertEqual(response.status_code, 400)
        self.assertEqual(get_user_model().objects.count(), 0)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_registered_account_can_use_existing_password_reset(self):
        self.assertEqual(self.post().status_code, 201)
        response = self.client.post(reverse("password_reset_request"),
            json.dumps({"email": "person@example.com"}), content_type="application/json")
        self.assertEqual(response.status_code, 202)
        self.assertEqual(len(mail.outbox), 0)
        self.assertTrue(PasswordResetRequest.objects.filter(email="person@example.com", status="pending").exists())

    def test_json_only_post_and_request_throttling(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)
        self.assertEqual(self.client.post(self.url, self.data).status_code, 415)
        cache.clear()
        self.data["email"] = "bad"
        for _ in range(5):
            self.assertEqual(self.post().status_code, 400)
        self.assertEqual(self.post().status_code, 429)
