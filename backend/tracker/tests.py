from django.test import SimpleTestCase
from django.urls import reverse


class HealthTests(SimpleTestCase):
    def test_frontend_can_read_health(self):
        response = self.client.get(
            reverse("health"), HTTP_ORIGIN="http://localhost:5173"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertEqual(
            response.headers["Access-Control-Allow-Origin"],
            "http://localhost:5173",
        )

    def test_other_origins_are_not_allowed(self):
        response = self.client.get(
            reverse("health"), HTTP_ORIGIN="https://example.com"
        )
        self.assertNotIn("Access-Control-Allow-Origin", response.headers)

    def test_health_is_read_only(self):
        self.assertEqual(self.client.post(reverse("health")).status_code, 405)
