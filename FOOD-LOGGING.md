# Manual food logging

The food flow is now: log in → Add manually → enter foods → Review record → Confirm → View history. A meal can contain up to 50 foods. Choose Breakfast, Brunch, Morning snack (Elevenses), Lunch, Afternoon tea, Dinner, Supper or Snack. Set the date and add a time if known. Quantity and unit are optional together; missing amounts stay unknown. History supports editing and deletion, including an explicit deletion confirmation.

The previous login button was a placeholder. It now verifies an existing registered email/password through Django and carries an in-memory authentication token on food API requests. Each account can only access its own meals. Restarting the app requires signing in again; saved records remain in SQLite.

## Run on macOS

In the TrackTalk root, start the backend:

```bash
cd backend
./.venv/bin/python -m pip install -r requirements.txt
./.venv/bin/python manage.py migrate
./.venv/bin/python manage.py runserver
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
| GET, POST | `/api/activity-records/` | List owned activities or create one |
| GET, PUT, PATCH, DELETE | `/api/activity-records/<id>/` | Read, update or delete an owned activity |

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

In Add record, choose Activity → Add manually. Enter an activity name, a duration in whole minutes and a date. Time is optional. Review the draft before confirming. History supports viewing, editing and deleting activities, with All, Food and Activity filters. In All, timed activities are inserted by time and untimed activities appear at the end.

## AI food logging and recommendations

TrackTalk uses the OpenAI Responses API from Django. The default model is
`gpt-6-luna`. Use `OPENAI_MODEL` to select another model with Structured Outputs
and support for reasoning effort `none`.

On macOS, start from the TrackTalk folder. On the first run, use the setup
option. Paste the full OpenAI API key once at the hidden terminal prompt and
press Return. The script checks the key, saves it in macOS Keychain, and
verifies that the saved value matches before starting the backend.

```zsh
./start-backend.sh --set-api-key
```

For later runs, start the backend with `./start-backend.sh`. Use the setup
option again when replacing the key. An existing `OPENAI_API_KEY` environment
variable takes precedence on regular runs.

On Windows, open PowerShell in the TrackTalk folder. Configure the key once
per Windows user and computer. Paste the key at the masked prompt.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-backend.ps1 -SetApiKey
```

For later runs, omit `-SetApiKey`. Windows encrypts the saved credential for
that local user in `%LOCALAPPDATA%\TrackTalk`. Use the setup option again to
replace the key. The normal startup command also works with a process-level
`OPENAI_API_KEY`.

For a shared deployment, set `OPENAI_API_KEY` in the hosted Django service.
Build Flutter with `--dart-define=API_BASE_URL=https://your-backend.example`
using the deployed HTTPS address. People sign in to TrackTalk with their
app accounts. AI requests are billed to the OpenAI project used by Django.

In **+ → Food**, type a description and send it to review the draft before
confirming. This uses `POST /api/food-records/parse/` with the existing login token.
The draft preserves explicitly provided times and quantities. For a draft
without a meal type, the editor asks the user to choose one.

**Home** and **Food → This week** use `GET /api/food-recommendations/` to show food
groups and a suggestion based on the user's logged week (Monday to Sunday in
the UK). AI selects from suggestions grounded in the NHS Eatwell Guide.
When AI is unavailable, the recommendation uses a preset suggestion. Manual
recording is available alongside text entry.
