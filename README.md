# TrackTalk

A conversational food and activity tracker built with Flutter and Django.

## Project brief

For this project the student will design and implement a mobile or web application supporting conventional and natural-language or voice-based logging of food and activity. For example, a user might enter: "For breakfast I had porridge with milk, blueberries and a banana." The system should convert this into structured, editable entries. Authoritative UK guidance (such as the [UK Eatwell Guide](https://www.gov.uk/government/publications/the-eatwell-guide)) should be used where health/nutritional information is presented rather than allowing an AI system to invent advice. The main CS challenge is reliable natural-language interaction and structured information extraction, rather than creating a plain AI nutrition adviser. However, AI APIs could be used.

## Current implementation

- Django health endpoint: `/api/health/`.
- SQLite development database.
- Flutter connection page with loading, success, failure and retry states.
- CORS restricted to local frontend origins.
- Three backend tests and two Flutter widget tests.

Food logging, authentication, natural-language extraction and voice input are not implemented yet.

## Prerequisites

Python 3.13, Flutter stable, Git and Chrome. Verified with Flutter 3.47.7 and Dart 3.13.5.
Flutter SDK on this machine: `C:\Users\Abel\develop\flutter`.
Restart your IDE after installation to refresh its terminal PATH.
Android project files are included, but Android SDK licenses still need acceptance before Android development.

## Start locally

From the TrackTalk root directory, open two PowerShell terminals.
Start Django in the first terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-backend.ps1
```

Start Flutter in the second terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-frontend.ps1
```

The policy option affects only the new PowerShell process and does not change the machine policy.
Open http://localhost:5173 and click **Check connection**.
Success displays **Connected to TrackTalk API.**
Backend URL: http://127.0.0.1:8000/api/health/.
Press Ctrl+C in the relevant terminal to stop a server. Run only one server per port.

For a standalone preview without the debug loader, use this instead of the frontend command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-preview.ps1
```

The preview builds the app and serves it locally. Restart it after code changes; it does not provide hot reload.

## Layout

- `backend/config/`: Django settings and routes.
- `backend/tracker/`: Application code and endpoint tests.
- `backend/requirements.txt`: Locked Python dependencies.
- `frontend/lib/main.dart`: Flutter application entry point.
- `frontend/test/`: Widget tests.
- `frontend/android/` and `frontend/web/`: Generated platform projects.
- `frontend/pubspec.yaml` and `frontend/pubspec.lock`: Flutter dependencies.

The original empty `HomePage.dart` is preserved; it is not the application entry point.

## IntelliJ IDEA

Install the Flutter plugin and its required Dart plugin from **Settings > Plugins > Marketplace**, then restart the IDE.
Open `frontend` as a Flutter project, select Chrome and run `lib/main.dart`.
Set the Flutter SDK path to `C:\Users\Abel\develop\flutter` if necessary.
Alternatively, keep TrackTalk open and use the root startup scripts.
The backend interpreter is `backend\.venv\Scripts\python.exe`.

## Restore dependencies

```powershell
cd backend
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
cd ..\frontend
flutter pub get
```

## Verification

```powershell
cd backend
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py test
cd ..\frontend
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
```

## GitHub

Remote: https://github.com/Abelxucc/conversation-food-and-activity-tracker.git

Local `main` tracks `origin/main` and preserves the existing history. No changes were pushed automatically.
Review and publish the changes yourself:

```powershell
git status
git add .
git commit -m "Set up Django backend and Flutter frontend"
git push origin main
```

Virtual environments, databases, secrets, IDE settings and build output are ignored.
Commit dependency manifests, the Flutter lockfile and Django migrations.

## Scope

Servers bind to the local machine. CORS allows only `http://localhost:5173` and `http://127.0.0.1:5173`.
Django settings are for local development and require production configuration before public deployment.
Android emulator networking needs a separate API base URL; the default loopback URL is for local web development.
The next milestone is manually creating, listing and editing food entries before adding language extraction.

References: [Flutter installation](https://docs.flutter.dev/install/manual), [Django tutorial](https://docs.djangoproject.com/en/5.2/intro/tutorial01/).
