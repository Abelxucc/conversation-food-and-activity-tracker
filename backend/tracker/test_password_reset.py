import json
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.test import Client, TestCase
from django.urls import reverse

from .models import PasswordResetRequest


class PasswordResetRequestTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = get_user_model().objects.create_user(
            username="reset-test", email="person@example.com", password="Original-pass-72!"
        )
        self.url = reverse("password_reset_request")

    def post(self, data):
        return self.client.post(self.url, json.dumps(data), content_type="application/json")

    def test_request_is_persisted_without_changing_password_or_sending_email(self):
        with patch("django.core.mail.send_mail") as send_mail:
            response = self.post({"email": "Person@Example.com"})
        self.assertEqual(response.status_code, 202)
        ticket = PasswordResetRequest.objects.get()
        self.assertEqual(ticket.email, "person@example.com")
        self.assertEqual(ticket.status, PasswordResetRequest.Status.PENDING)
        self.assertIsNone(ticket.account)
        self.assertIsNone(ticket.handled_at)
        self.assertIsNone(ticket.identity_verified_by)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))
        send_mail.assert_not_called()
        self.assertEqual(set(response.json()), {"detail"})

    def test_known_and_unknown_addresses_have_same_response(self):
        known = self.post({"email": self.user.email})
        unknown = self.post({"email": "unknown@example.com"})
        self.assertEqual(known.status_code, unknown.status_code)
        self.assertEqual(known.json(), unknown.json())
        self.assertEqual(PasswordResetRequest.objects.count(), 2)

    def test_duplicate_pending_request_is_not_added_again(self):
        first = self.post({"email": self.user.email})
        second = self.post({"email": "PERSON@example.com"})
        self.assertEqual(first.json(), second.json())
        self.assertEqual(PasswordResetRequest.objects.count(), 1)
        ticket = PasswordResetRequest.objects.get()
        ticket.status = PasswordResetRequest.Status.CLOSED
        ticket.save()
        self.assertEqual(self.post({"email": self.user.email}).status_code, 202)
        self.assertEqual(PasswordResetRequest.objects.count(), 2)

    def test_invalid_email_and_request_throttling(self):
        self.assertEqual(self.post({"email": "bad"}).status_code, 400)
        for _ in range(4):
            self.assertEqual(self.post({"email": self.user.email}).status_code, 202)
        self.assertEqual(self.post({"email": self.user.email}).status_code, 429)

    def test_public_request_cannot_supply_a_new_password(self):
        response = self.post({"email": self.user.email, "new_password": "Injected-password-72!"})
        self.assertEqual(response.status_code, 202)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))
        old = self.client.post("/api/auth/password-reset/confirm/",
            json.dumps({"email": self.user.email, "new_password": "Injected-password-72!"}),
            content_type="application/json")
        self.assertEqual(old.status_code, 404)

    def test_json_post_only_and_admin_list_is_not_public(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)
        self.assertEqual(self.client.post(self.url, {"email": self.user.email}).status_code, 415)
        response = self.client.get(reverse("admin:tracker_passwordresetrequest_changelist"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/admin/login/", response.url)


class AdministratorPasswordResetTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="person", email="person@example.com", password="Original-pass-72!"
        )
        self.administrator = get_user_model().objects.create_superuser(
            username="test-admin", email="admin@example.com", password="Administrator-pass-73!"
        )
        self.ticket = PasswordResetRequest.objects.create(email=self.user.email)
        self.url = reverse("admin:tracker_passwordresetrequest_reset_password", args=[self.ticket.pk])
        self.data = {
            "new_password1": "New-river-password-74!",
            "new_password2": "New-river-password-74!",
            "identity_verified": "on",
            "admin_notes": "Verified in person for the local test.",
        }

    def assert_original_password(self):
        self.user.refresh_from_db()
        self.ticket.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))
        self.assertEqual(self.ticket.status, PasswordResetRequest.Status.PENDING)

    def test_unauthenticated_and_ordinary_users_cannot_reset(self):
        self.assertEqual(self.client.post(self.url, self.data).status_code, 302)
        self.client.force_login(self.user)
        self.assertEqual(self.client.post(self.url, self.data).status_code, 302)
        self.assert_original_password()

    def test_staff_need_request_permission_and_user_change_permission(self):
        staff = get_user_model().objects.create_user(username="reviewer", password="Reviewer-pass-75!", is_staff=True)
        permission = Permission.objects.get(codename="change_passwordresetrequest", content_type__app_label="tracker")
        staff.user_permissions.add(permission)
        self.client.force_login(staff)
        self.assertEqual(self.client.post(self.url, self.data).status_code, 403)
        self.assert_original_password()

    def test_identity_verification_and_notes_are_required(self):
        self.client.force_login(self.administrator)
        data = {**self.data, "identity_verified": ""}
        response = self.client.post(self.url, data)
        self.assertEqual(response.status_code, 200)
        self.assertIn("identity_verified", response.context["form"].errors)
        data = {**self.data, "admin_notes": ""}
        response = self.client.post(self.url, data)
        self.assertIn("admin_notes", response.context["form"].errors)
        self.assert_original_password()

    def test_success_records_handler_and_cannot_be_replayed(self):
        self.client.force_login(self.administrator)
        response = self.client.post(self.url, self.data)
        self.assertEqual(response.status_code, 302)
        self.user.refresh_from_db()
        self.ticket.refresh_from_db()
        self.assertTrue(self.user.check_password(self.data["new_password1"]))
        self.assertNotEqual(self.user.password, self.data["new_password1"])
        self.assertEqual(self.ticket.status, PasswordResetRequest.Status.COMPLETED)
        self.assertEqual(self.ticket.account, self.user)
        self.assertEqual(self.ticket.handled_by, self.administrator)
        self.assertEqual(self.ticket.identity_verified_by, self.administrator)
        self.assertIsNotNone(self.ticket.identity_verified_at)
        self.assertEqual(self.ticket.admin_notes, self.data["admin_notes"])
        self.assertNotIn(self.data["new_password1"], self.ticket.admin_notes)
        self.assertEqual(self.client.post(self.url, self.data).status_code, 403)

    def test_password_policy_and_confirmation_are_enforced(self):
        self.client.force_login(self.administrator)
        response = self.client.post(self.url, {**self.data, "new_password1": "123", "new_password2": "123"})
        self.assertTrue(response.context["form"].errors)
        response = self.client.post(self.url, {**self.data, "new_password2": "does-not-match"})
        self.assertTrue(response.context["form"].errors)
        self.assert_original_password()

    def test_csrf_is_required_for_administrator_password_changes(self):
        protected_client = Client(enforce_csrf_checks=True)
        protected_client.force_login(self.administrator)
        self.assertEqual(protected_client.post(self.url, self.data).status_code, 403)
        self.assert_original_password()

    def test_unknown_account_is_not_reset_and_requests_can_be_closed(self):
        self.ticket.email = "unknown@example.com"
        self.ticket.save()
        self.client.force_login(self.administrator)
        response = self.client.post(self.url, self.data)
        self.assertIsNone(response.context["form"])
        self.assert_original_password()
        self.client.post(reverse("admin:tracker_passwordresetrequest_changelist"), {
            "action": "close_requests", "_selected_action": [str(self.ticket.pk)],
        })
        self.ticket.refresh_from_db()
        self.assertEqual(self.ticket.status, PasswordResetRequest.Status.CLOSED)
        self.assertEqual(self.ticket.handled_by, self.administrator)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-pass-72!"))
