# Account registration

From the login page choose **Sign up here!**. Registration is one page with:

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

The form only displays success after the server confirms account creation.
There are no weight, height or other profile questions. Email and phone ownership
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
