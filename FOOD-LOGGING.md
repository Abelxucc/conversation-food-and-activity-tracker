# Manual food logging

The food flow is now: log in → Add manually → enter foods → Review record → Confirm → View history. A meal can contain up to 50 foods. Choose breakfast, lunch, dinner or snack, plus date and time. Quantity and unit are optional together; missing amounts stay unknown. History supports editing and deletion, including an explicit deletion confirmation.

The previous login button was a placeholder. It now verifies an existing registered email/password through Django and carries an in-memory authentication token on food API requests. Each account can only access its own meals. Restarting the app requires signing in again; saved records remain in SQLite.

## Run on macOS

In the TrackTalk root, start the backend:

```bash
cd backend
source .venv/bin/activate
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

In a second terminal:

```bash
cd ~/Desktop/TrackTalk/frontend
flutter pub get
flutter run -d chrome --web-port 5173
```

Register an account if needed, then log in. Local iOS simulators use the same default backend address; Android emulators use `10.0.2.2`. A physical phone requires an appropriate `API_BASE_URL` and backend network configuration.

## Database and API

`FoodRecord` stores the account, meal type and timestamp; its `FoodEntry` children store names and optional quantities/units. A complete meal saves in a single database transaction. Editing replaces its food items together; deleting the meal removes all its children.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/auth/login/` | Verify email/password and return a token |
| GET, POST | `/api/food-records/` | List owned meals or create one |
| GET, PUT, PATCH, DELETE | `/api/food-records/<id>/` | Read, update or delete an owned meal |
| GET | `/api/food-entries/` | Legacy read view, restricted to owned food items |

Food requests use `Authorization: Token <token>`. The formerly public standalone food-entry POST is replaced by the meal endpoint. Old unowned development entries are retained by migration but never exposed to signed-in users. Existing accounts/profiles and other database data are retained.

The existing SQLite database must be migrated before starting the updated app. Schema changes are committed as Django migrations; do not commit the database itself.

### History order and optional times

For each selected local day, History orders main meals as breakfast → lunch → dinner, with records in the same meal ordered by time. Timed snacks are inserted before the next meal with a later time; equal-time snacks follow that meal. Untimed snacks always follow all meals and timed snacks. Ties use ascending record IDs, so server response order and refreshes do not change the layout.

Time is now optional in the manual editor and can be cleared. The API persists `time_specified` alongside `eaten_at`; date-only records send local midnight and display “Time not specified”. Midnight is also a valid explicit time when the flag is true. Untimed main meals use 08:00, 12:00 and 18:00 as internal insertion anchors only; these are never displayed or stored as chosen times. Explicitly entered main-meal times do not override the breakfast/lunch/dinner order.

Migration 0006 preserves existing records and their timestamps with `time_specified=True`, also retaining compatibility with older API clients. Earlier versions did not distinguish a chosen time from the default logging time, so old missing times cannot be recovered automatically. Clear an old record's time in the editor if it was not specified.

## Verification

```bash
cd backend
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py test tracker
cd ../frontend
flutter analyze
flutter test
```

Backend coverage includes account isolation, authentication, input validation, transaction rollback and meal CRUD. Flutter coverage includes login, review-before-save, retry with the draft preserved, history editing/deletion and small-screen form access.

For a manual persistence check: create a meal, stop and restart Django and Flutter, sign in again, and open Food history. Edit the meal, reopen history to check the updated details, then delete it.

Activity logging and natural-language/AI extraction are later work. This change implements the manual-food portion of the supplied reference flow. The app does not infer calories, food amounts or nutritional advice.
