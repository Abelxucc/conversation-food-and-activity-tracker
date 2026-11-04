#!/bin/zsh
set -euo pipefail

cd -- "${0:A:h}/backend"
if [[ ! -x ./.venv/bin/python ]]; then
  printf 'Set up the backend virtual environment before starting TrackTalk. See FOOD-LOGGING.md.\n' >&2
  exit 1
fi

keychain_account=$(/usr/bin/id -un)
keychain_service='TrackTalk OpenAI API Key'

setting_api_key=false
if [[ ${1:-} == --set-api-key ]]; then
  setting_api_key=true
  printf 'Paste your OpenAI API key and press Return: '
  IFS= read -rs OPENAI_API_KEY || exit 1
  printf '\n'
  shift
elif [[ -z ${OPENAI_API_KEY:-} ]]; then
  if ! OPENAI_API_KEY=$(/usr/bin/security find-generic-password -a "$keychain_account" -s "$keychain_service" -w 2>/dev/null); then
    OPENAI_API_KEY=''
    printf 'To enable AI on this Mac, run ./start-backend.sh --set-api-key from the TrackTalk folder.\n'
  fi
fi

if [[ -n $OPENAI_API_KEY && ! $OPENAI_API_KEY =~ ^sk-[A-Za-z0-9_-]{20,}$ ]]; then
  printf '%s\n' 'Expected the full OpenAI API key from the creation dialog.' \
    'Run ./start-backend.sh --set-api-key and paste the complete key.' >&2
  exit 1
fi

if $setting_api_key; then
  if [[ -z $OPENAI_API_KEY ]]; then
    printf 'Enter an API key to complete setup.\n' >&2
    exit 1
  fi
  OPENAI_API_KEY="$OPENAI_API_KEY" ./.venv/bin/python - <<'PYTHON'
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

request = Request(
    "https://api.openai.com/v1/models",
    headers={"Authorization": "Bearer " + os.environ["OPENAI_API_KEY"]},
)
try:
    with urlopen(request, timeout=8):
        print("OpenAI accepted the API key.")
except HTTPError as error:
    try:
        code = json.loads(error.read(16000)).get("error", {}).get("code")
    except (ValueError, AttributeError):
        code = None
    if error.code == 401 and code not in ("insufficient_permissions", "missing_scope"):
        print(
            "OpenAI rejected the key. Create a new secret key in the OpenAI API "
            "dashboard and paste the full value at the setup prompt.",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"Could not verify model-list access (HTTP {error.code}). Starting TrackTalk.")
except (URLError, TimeoutError):
    print("Could not reach OpenAI for the key check. Starting TrackTalk.")
PYTHON
  # Read via zsh and pass the complete key to security on stdin. The built-in
  # password prompt truncates long keys, and arguments would expose the secret.
  if ! printf 'add-generic-password -U -a "%s" -s "%s" -w "%s"\n' \
      "$keychain_account" "$keychain_service" "$OPENAI_API_KEY" |
      /usr/bin/env -u OPENAI_API_KEY /usr/bin/security -q -i >/dev/null 2>&1; then
    printf 'Could not save the API key in macOS Keychain.\n' >&2
    exit 1
  fi
  if ! saved_api_key=$(/usr/bin/env -u OPENAI_API_KEY /usr/bin/security find-generic-password \
      -a "$keychain_account" -s "$keychain_service" -w 2>/dev/null) ||
      [[ $saved_api_key != "$OPENAI_API_KEY" ]]; then
    printf 'Could not read back the complete API key from Keychain.\n' >&2
    exit 1
  fi
  unset saved_api_key
  printf 'API key saved in macOS Keychain.\n'
fi

export OPENAI_API_KEY
exec ./.venv/bin/python manage.py runserver "$@"
