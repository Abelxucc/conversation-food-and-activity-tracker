# Manual food logging

The food flow is now: log in → Add manually → enter foods → Review record → Confirm → View history. A meal can contain up to 50 foods. Choose Breakfast, Brunch, Morning snack (Elevenses), Lunch, Afternoon tea, Dinner, Supper or Snack. Set the date and add a time if known. Quantity and unit are optional together; missing amounts stay unknown. History supports editing and deletion, including an explicit deletion confirmation.

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

For each selected local day, History orders meals as Breakfast → Brunch → Morning snack (Elevenses) → Lunch → Afternoon tea → Dinner → Supper, with records in the same meal ordered by time. Timed Snack records are inserted before the next meal with a later time. Equal-time snacks follow that meal. Untimed Snack records always follow all meals and timed snacks. Ties use ascending record IDs, so server response order and refreshes do not change the layout.

Time is optional in the manual editor and can be cleared. The API persists `time_specified` alongside `eaten_at`. Date-only records send local midnight and display “Time not specified”. Midnight is also a valid explicit time when the flag is true. Untimed meals use 08:00, 10:30, 11:00, 12:00, 16:00, 18:00 and 22:00 as sorting slots in meal order.

Migration 0006 preserves existing records and their timestamps with `time_specified=True`, also retaining compatibility with older API clients. Earlier versions did not distinguish a chosen time from the default logging time, so old missing times cannot be recovered automatically. Clear an old record's time in the editor if it was not specified.

## Me and navigation

After login, a persistent tab bar animates its selection between Home, Food, Add record, Activity and Me. The food flow uses its own navigator, so switching to Me and back preserves manual input, review drafts and History. Food writes and sign out temporarily disable tab switching. The bar respects the system's reduced-motion setting and hides above an open keyboard.

Me follows the existing rounded-card design. Edit my profile, Settings and About us are disabled and marked “Coming soon”; Home, Food and Activity also show placeholders. Sign out sends an authenticated `POST /api/auth/logout/`, revokes the server token, and clears the authenticated routes before showing a fresh login page. Already-expired tokens can be cleared locally; connection failures keep the session in place and offer retry. Existing food records are preserved.

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
