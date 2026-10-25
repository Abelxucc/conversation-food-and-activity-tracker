# Account registration

From the login page choose **Sign up here!**. The account details page contains:

- Email address
- Confirm email address
- Password
- Phone number

The two email entries must match. Emails are stored in lowercase and cannot be
registered twice, regardless of case. Passwords must pass Django's configured
password validators; only a hash is stored. Phone numbers accept common spacing
and punctuation and are stored as digits with an optional leading `+`.

The `POST /api/auth/register/` endpoint accepts JSON with `email`, `confirm_email`,
`password`, and `phone_number`. A successful request returns HTTP 201. It creates
a Django authentication user plus the linked `tracker_accountprofile` record in
`backend/db.sqlite3`. Both records are created in one transaction. A database
constraint prevents duplicate emails in account profiles.

**Create account** first checks these fields locally, then calls
`POST /api/auth/register/validate/` to check email uniqueness and Django's
password/phone rules. An existing email is reported on the account form before
profile questions are shown. This check creates no records. A successful
HTTP 204 opens the profile steps:

1. Gender (including Prefer not to say)
2. Height in centimetres or feet/inches
3. Weight in kilograms or pounds
4. Age in whole years

Back moves to the previous step and retains the draft values. Returning from
gender to the account form also retains the profile draft for this session.
Nothing is saved until **Continue** on the age page: the account details and all
four profile answers are sent in one registration request. Django creates the
user and profile atomically and stores only a password hash. Success is shown
only after HTTP 201. Errors keep the draft and allow retrying or editing the
account details. Drafts and the password are held in memory, never local storage.

The JSON request also includes `gender`, `height_cm`, `weight_kg`, and `age`.
Older clients can omit all four; if any are supplied, all four are required.
The server validates the choices, numeric precision and input ranges. These
are form input limits, not health guidance or recommended measurements.

To try the full flow, open `/register` (on Flutter web: `/#/register`). The
older `/profile/gender` deep link starts with the account form, because a direct
link has no account draft. The backend must be running for the initial account
check and the final submission. Uniqueness is checked again on final submission.

The height, weight and age screens follow the supplied designs, including unit
switches, subtitles and illustrations. Unit switches convert the current entry;
the database always stores height in cm and weight in kg, to two decimal places.

Email and phone ownership
verification, actual sign-in, Google sign-in and automatic login are not part of
this change. Registered accounts can use the existing password-reset flow.

## Run after pulling on another computer

From the project root on Windows:

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py migrate
.\backend\.venv\Scripts\python.exe backend\manage.py runserver 127.0.0.1:8000
```

In a second terminal:

```powershell
cd frontend
flutter pub get
flutter run
```

On macOS use `backend/.venv/bin/python` as the Python interpreter instead. The
SQLite database is local and ignored by Git; run migrations on each computer.
The migration files and source code should be committed. See `RESET-DEMO.md`
for the administrator-assisted password reset workflow.
