# Administrator-assisted password reset

The login screen's **Forgot password?** link opens an email-only request form.
The form shares the login page's illustration, colours, input styling and buttons.

Submitting the form stores a pending request in the local SQLite database. It
does not send email, generate a reset link or change any password. The screen
asks the user to contact the administrator for identity verification.

## Start locally

From the TrackTalk root:

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py migrate
.\backend\.venv\Scripts\python.exe backend\manage.py runserver 127.0.0.1:8000
```

Run Flutter from a second terminal:

```powershell
cd frontend
flutter run
```

Use **Forgot password?**, enter the registered email, and choose **Request
password reset**. A successful response says **Request submitted**. Repeated
requests for the same email share a pending request rather than creating duplicates.

## Review and handle requests

1. Open `http://127.0.0.1:8000/admin/` on the computer and sign in as an administrator.
   If no administrator exists, create one by running the following command in a
   separate terminal and entering your chosen administrator details:

   ```powershell
   .\backend\.venv\Scripts\python.exe backend\manage.py createsuperuser
   ```

2. Open **Tracker > Password reset requests**, filter by **Pending**, and select
   the request. Account profiles in the admin list show the registered account
   email and phone number for reference.
3. Independently verify the person's identity. For a classroom demonstration,
   the developer can act as administrator and verify the test user in person.
   Knowing the email or phone number alone is not proof of ownership.
4. Choose **Review identity and reset password**. Enter and confirm the new
   password, check that identity was verified, and record the verification method
   in the notes. Never record the password in notes.
5. Submit. Django saves the password hash and marks the request **Completed**,
   recording the administrator and time. A handled request cannot be reused.

Requests for unknown or ambiguous email addresses cannot reset an account. Use
the list action **Close selected pending requests without resetting passwords**
for requests that cannot be verified. The same public response is used for known
and unknown addresses so account existence is not exposed.

Only administrators with both request-handling and user-change permissions can
reset passwords. The old public token-confirm endpoint has been removed. No
administrator account or privileged password is created automatically.

Registration and administrator-assisted recovery now write to the database.
Actual Flutter sign-in and Google sign-in remain separate pending features.

## Tests

```powershell
.\backend\.venv\Scripts\python.exe backend\manage.py test tracker
cd frontend
flutter test
flutter analyze --no-fatal-infos
```

After pulling on another computer, run database migrations there too. The local
SQLite database, accounts, requests and administrator login are not pushed to Git.
