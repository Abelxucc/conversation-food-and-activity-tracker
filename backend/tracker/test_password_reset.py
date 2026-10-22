import json
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.core import mail
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode


@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class PasswordResetTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = get_user_model().objects.create_user(
            username="reset-test", email="person@example.com", password="Original-pass-72!"
        )
        self.request_url = reverse("password_reset_request")
        self.confirm_url = reverse("password_reset_confirm")

    def post(self, url, data):
        return self.client.post(url, json.dumps(data), content_type="application/json")

    def credentials(self):
        return {
            "uid": urlsafe_base64_encode(force_bytes(self.user.pk)),
            "token": default_token_generator.make_token(self.user),
            "new_password": "New-river-pass-83!",
            "confirm_password": "New-river-pass-83!",
        }

    def test_request_does_not_reveal_account_or_expose_token(self):
        known = self.post(self.request_url, {"email": self.user.email})
        unknown = self.post(self.request_url, {"email": "unknown@example.com"})
        self.assertEqual(known.status_code, 200)
        self.assertEqual(known.json(), unknown.json())
        self.assertEqual(set(known.json()), {"detail"})
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("http://localhost:5173/#/reset-password/", mail.outbox[0].body)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))

    def test_console_backend_prints_a_link_without_email_service(self):
        with override_settings(EMAIL_BACKEND="django.core.mail.backends.console.EmailBackend"):
            with patch("sys.stdout") as output:
                response = self.post(self.request_url, {"email": self.user.email})
        self.assertEqual(response.status_code, 200)
        printed = "".join(call.args[0] for call in output.write.call_args_list if call.args)
        self.assertIn("http://localhost:5173/#/reset-password/", printed)

    def test_token_is_required_and_single_use(self):
        data = self.credentials()
        missing = {"email": self.user.email, "new_password": data["new_password"]}
        self.assertEqual(self.post(self.confirm_url, missing).status_code, 400)
        response = self.post(self.confirm_url, data)
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(data["new_password"]))
        self.assertFalse(self.user.check_password("Original-pass-72!"))
        self.assertNotEqual(self.user.password, data["new_password"])
        self.assertNotIn("_auth_user_id", self.client.session)
        data["new_password"] = data["confirm_password"] = "Another-river-pass-91!"
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("New-river-pass-83!"))

    def test_invalid_and_expired_tokens_do_not_change_password(self):
        data = self.credentials()
        token = data["token"]
        data["token"] = "not-a-valid-token"
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        data["token"] = token
        future = default_token_generator._now() + timedelta(seconds=1801)
        with patch.object(default_token_generator, "_now", return_value=future):
            self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))

    def test_password_policy_and_confirmation_are_enforced(self):
        data = self.credentials()
        data["confirm_password"] = "different-password"
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        data["new_password"] = data["confirm_password"] = "123"
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))

    def test_inactive_and_passwordless_accounts_are_not_reset(self):
        data = self.credentials()
        self.user.is_active = False
        self.user.save()
        self.post(self.request_url, {"email": self.user.email})
        self.assertEqual(len(mail.outbox), 0)
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        self.user.is_active = True
        self.user.set_unusable_password()
        self.user.save()
        self.post(self.request_url, {"email": self.user.email})
        self.assertEqual(len(mail.outbox), 0)

    def test_invalid_email_and_request_throttling(self):
        self.assertEqual(self.post(self.request_url, {"email": "bad"}).status_code, 400)
        for _ in range(4):
            self.assertEqual(self.post(self.request_url, {"email": "unknown@example.com"}).status_code, 200)
        self.assertEqual(self.post(self.request_url, {"email": "unknown@example.com"}).status_code, 429)

    def test_malformed_uid_and_non_json_input_are_rejected(self):
        data = self.credentials()
        data["uid"] = "invalid-user"
        self.assertEqual(self.post(self.confirm_url, data).status_code, 400)
        response = self.client.post(self.request_url, {"email": self.user.email})
        self.assertEqual(response.status_code, 415)
