# Password reset demo

The login screen's **Forgot password?** link opens the Flutter reset screen.
It shares the login screen's illustration, colours, input styling and buttons.

The demo uses Django's password-reset tokens and password validation. No email
provider is needed: Django prints the reset email and one-time link to its
terminal. Links expire after 30 minutes and stop working after a successful reset.
Only active Django users with usable passwords can request a link.

## Run locally

In one terminal, from the TrackTalk root:

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py migrate
.\backend\.venv\Scripts\python.exe backend\manage.py runserver 127.0.0.1:8000
```

In another terminal:

```powershell
cd frontend
flutter run -d chrome --web-port 5173
```

Use an email address belonging to a Django test user. If needed, create a test
account first with `backend\manage.py createsuperuser` using the same Python
interpreter; enter a test email and password when prompted. Registration and
login in Flutter are still placeholders; a completed reset does not implement
those features.

1. Click **Forgot password?**, enter the test user's email, and request a link.
2. Copy the full `http://localhost:5173/#/reset-password/...` link from the Django
   terminal and open it in your browser. No code needs to be typed into the app.
3. Enter and confirm a new password. Django validates it and stores its hash.
4. Return to log in. Reusing the link must show an invalid/expired-link error.

For an unknown email the screen shows the same response, but Django does not
print a reset email. API responses never contain reset tokens or links.

## Android emulator

The default API address is `http://10.0.2.2:8000` for Android emulators and
`http://127.0.0.1:8000` for browser and desktop builds. The debug Android manifest
allows HTTP only for these local development hosts. You can override the API
address with `--dart-define=API_BASE_URL=...`.

You can request a link in the emulator and complete the reset in your computer's
browser, with the Flutter web app running on port 5173. Android app links are not
configured. `localhost` inside the emulator points to the emulator, not your PC.

## Tests

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py test tracker
cd frontend
flutter test
flutter analyze --no-fatal-infos
```

The Django tests use a separate temporary test database. They cover generic
responses, console delivery, missing/invalid/expired tokens, token reuse,
password policy, inactive/passwordless users, and request throttling.

The console backend is for local development. Real users need a private delivery
channel, such as email, or another previously enrolled recovery method. Configure
the email backend, trusted frontend URL, HTTPS, and a shared throttling cache
before an external deployment. Email alone is never proof of account ownership.
