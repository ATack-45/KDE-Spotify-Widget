#!/usr/bin/env python3
"""
Spotify OAuth2 PKCE setup script for KDE Spotify Widget.
Uses only Python 3 stdlib — no pip installs needed.

Prerequisites:
  1. Create a Spotify app at https://developer.spotify.com/dashboard
  2. Add "http://localhost:8888/callback" as a Redirect URI in app settings
  3. Note down your Client ID and Client Secret

Usage:
  python3 setup_auth.py

The script will open a browser, handle the OAuth callback, and print
your refresh token. Paste it into the widget's Configure dialog.
"""

import hashlib
import base64
import secrets
import json
import urllib.parse
import urllib.request
import webbrowser
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread

REDIRECT_URI = "http://localhost:8888/callback"
AUTH_URL     = "https://accounts.spotify.com/authorize"
TOKEN_URL    = "https://accounts.spotify.com/api/token"
SCOPES       = (
    "user-read-currently-playing "
    "user-read-playback-state "
    "user-modify-playback-state "
    "playlist-read-private "
    "playlist-read-collaborative"
)

_callback_result = {"code": None, "error": None}


class _CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if "code" in params:
            _callback_result["code"] = params["code"][0]
            body = b"<html><body><h2>Authorization successful!</h2><p>You can close this tab.</p></body></html>"
        elif "error" in params:
            _callback_result["error"] = params["error"][0]
            body = b"<html><body><h2>Authorization failed.</h2><p>Check the terminal for details.</p></body></html>"
        else:
            body = b"<html><body><h2>Unexpected callback.</h2></body></html>"

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # suppress access log noise


def _pkce_pair():
    verifier  = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    digest    = hashlib.sha256(verifier.encode()).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
    return verifier, challenge


def _build_auth_url(client_id, state, code_challenge):
    params = {
        "client_id":             client_id,
        "response_type":         "code",
        "redirect_uri":          REDIRECT_URI,
        "scope":                 SCOPES,
        "state":                 state,
        "code_challenge_method": "S256",
        "code_challenge":        code_challenge,
    }
    return AUTH_URL + "?" + urllib.parse.urlencode(params)


def _exchange_code(client_id, client_secret, code, code_verifier):
    data = urllib.parse.urlencode({
        "grant_type":    "authorization_code",
        "code":          code,
        "redirect_uri":  REDIRECT_URI,
        "client_id":     client_id,
        "code_verifier": code_verifier,
    }).encode()

    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    req = urllib.request.Request(
        TOKEN_URL,
        data=data,
        headers={
            "Content-Type":  "application/x-www-form-urlencoded",
            "Authorization": f"Basic {credentials}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())


def main():
    print("=" * 60)
    print("  KDE Spotify Widget — One-Time Authorization Setup")
    print("=" * 60)
    print()
    print("Before running this script, make sure you have added:")
    print(f"  {REDIRECT_URI}")
    print("as a Redirect URI in your Spotify Developer Dashboard app.")
    print()

    client_id     = input("Enter your Spotify Client ID:     ").strip()
    client_secret = input("Enter your Spotify Client Secret: ").strip()

    if not client_id or not client_secret:
        print("\nError: Client ID and Client Secret are required.")
        sys.exit(1)

    code_verifier, code_challenge = _pkce_pair()
    state    = secrets.token_urlsafe(16)
    auth_url = _build_auth_url(client_id, state, code_challenge)

    # Start callback server in a background thread (handles one request)
    server = HTTPServer(("localhost", 8888), _CallbackHandler)
    thread = Thread(target=server.handle_request, daemon=True)
    thread.start()

    print("\nOpening browser to authorize the widget...")
    print("If it doesn't open automatically, visit:")
    print(f"  {auth_url}")
    print()
    webbrowser.open(auth_url)
    print("Waiting for Spotify callback (timeout: 2 minutes)...")

    thread.join(timeout=120)

    if _callback_result["error"]:
        print(f"\nSpotify returned an error: {_callback_result['error']}")
        sys.exit(1)

    if not _callback_result["code"]:
        print("\nTimeout: no callback received within 2 minutes.")
        print("Make sure the redirect URI is registered in your Spotify app settings.")
        sys.exit(1)

    print("Exchanging authorization code for tokens...")
    try:
        tokens = _exchange_code(client_id, client_secret, _callback_result["code"], code_verifier)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"\nToken exchange failed ({e.code}): {body}")
        sys.exit(1)

    refresh_token = tokens.get("refresh_token", "")
    if not refresh_token:
        print("\nError: No refresh_token in the Spotify response.")
        print("Full response:", json.dumps(tokens, indent=2))
        sys.exit(1)

    print()
    print("=" * 60)
    print("  SUCCESS! Copy the values below into the widget config.")
    print("  (Right-click widget → Configure)")
    print("=" * 60)
    print()
    print(f"  Client ID:     {client_id}")
    print(f"  Client Secret: {client_secret}")
    print(f"  Refresh Token: {refresh_token}")
    print()


if __name__ == "__main__":
    main()
