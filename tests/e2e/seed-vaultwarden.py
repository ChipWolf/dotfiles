#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["cryptography"]
# ///
"""Register a test user on a Vaultwarden instance and seed vault items.

Usage:
    python seed-vaultwarden.py <server_url> <email> <password> <items_json>

    items_json is a JSON array of {name, login_password} objects, e.g.:
    '[{"name":"wakatime-api-key","login_password":"test-key"}]'

Requires: cryptography (pip install cryptography)
"""

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import hmac as crypto_hmac
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC


def derive_master_key(password: str, email: str, iterations: int = 600000) -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=email.lower().encode(),
        iterations=iterations,
    )
    return kdf.derive(password.encode())


def derive_master_password_hash(master_key: bytes, password: str) -> str:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=password.encode(),
        iterations=1,
    )
    return base64.b64encode(kdf.derive(master_key)).decode()


def stretch_key(master_key: bytes) -> tuple[bytes, bytes]:
    enc_key = HKDFExpand(algorithm=hashes.SHA256(), length=32, info=b"enc").derive(
        master_key
    )
    mac_key = HKDFExpand(algorithm=hashes.SHA256(), length=32, info=b"mac").derive(
        master_key
    )
    return enc_key, mac_key


def encrypt_symmetric_key(enc_key: bytes, mac_key: bytes) -> str:
    """Encrypt a random symmetric key (Bitwarden type-2 format)."""
    sym_key = os.urandom(64)
    iv = os.urandom(16)
    cipher = Cipher(algorithms.AES(enc_key), modes.CBC(iv))
    encryptor = cipher.encryptor()
    pad_len = 16 - (len(sym_key) % 16)
    padded = sym_key + bytes([pad_len] * pad_len)
    ct = encryptor.update(padded) + encryptor.finalize()
    h = crypto_hmac.HMAC(mac_key, hashes.SHA256())
    h.update(iv + ct)
    mac = h.finalize()
    iv_b64 = base64.b64encode(iv).decode()
    ct_b64 = base64.b64encode(ct).decode()
    mac_b64 = base64.b64encode(mac).decode()
    return f"2.{iv_b64}|{ct_b64}|{mac_b64}"


def api_request(url: str, data: dict | None = None, token: str | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:  # nosec B310
            return json.loads(resp.read().decode()) if resp.status != 204 else {}
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()
        print(f"API error {e.code} on {url}: {body_text}", file=sys.stderr)
        raise


def api_request_raw(url: str, data: dict | None = None) -> str:
    """Like api_request but returns the raw response body as text."""
    headers = {"Content-Type": "application/json"}
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:  # nosec B310
            return resp.read().decode()
    except urllib.error.HTTPError as e:
        body_text = e.read().decode()
        print(f"API error {e.code} on {url}: {body_text}", file=sys.stderr)
        raise


def register(server: str, email: str, password: str) -> str:
    master_key = derive_master_key(password, email)
    master_hash = derive_master_password_hash(master_key, password)
    enc_key, mac_key = stretch_key(master_key)
    encrypted_key = encrypt_symmetric_key(enc_key, mac_key)
    base = server.rstrip("/")

    # Legacy single-step registration (Vaultwarden < 1.37.0 / Bitwarden < 2026.5.0).
    # Vaultwarden/Bitwarden deployments can expose registration under
    # /identity/accounts/register (current) or /api/accounts/register (legacy).
    legacy_payload = {
        "name": "CI Test User",
        "email": email,
        "masterPasswordHash": master_hash,
        "masterPasswordHint": "",
        "key": encrypted_key,
        "kdf": 0,
        "kdfIterations": 600000,
    }
    for endpoint in [
        f"{base}/identity/accounts/register",
        f"{base}/api/accounts/register",
    ]:
        try:
            api_request(endpoint, legacy_payload)
            return master_hash
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            raise

    # New two-step registration flow (Vaultwarden >= 1.37.0 / Bitwarden >= 2026.5.0).
    #
    # Step 1: request a verification token. When SIGNUPS_VERIFY is false (the
    # default), Vaultwarden returns the token directly in the response body so
    # callers in email-less CI environments can proceed immediately. The token
    # may be JSON-quoted (\"token\") in older 1.37.x builds; strip the quotes.
    # A 204 No Content response means email verification is required — that
    # path is not supported in this CI helper.
    send_raw = api_request_raw(
        f"{base}/identity/accounts/register/send-verification-email",
        {"email": email, "name": "CI Test User", "receiveMarketingEmails": False},
    )
    token = send_raw.strip().strip('"')
    if not token:
        raise RuntimeError(
            "Vaultwarden returned no registration token from send-verification-email. "
            "Ensure SIGNUPS_ALLOWED=true and SIGNUPS_VERIFY is unset or false."
        )

    # Step 2: complete registration with the token.
    # Field names changed from the legacy API: key→userSymmetricKey, kdf→kdfType.
    finish_payload = {
        "email": email,
        "masterPasswordHash": master_hash,
        "masterPasswordHint": "",
        "userSymmetricKey": encrypted_key,
        "kdfType": 0,
        "kdfIterations": 600000,
        "emailVerificationToken": token,
    }
    api_request(f"{base}/identity/accounts/register/finish", finish_payload)
    return master_hash


def main() -> None:
    if len(sys.argv) != 5:
        print(
            f"Usage: {sys.argv[0]} <server_url> <email> <password> <items_json>",
            file=sys.stderr,
        )
        sys.exit(1)

    server, email, password, items_json = sys.argv[1:]
    items = json.loads(items_json)

    print(f"Registering {email} on {server}...")
    register(server, email, password)
    print("Registration successful.")

    print(f"Seeding {len(items)} vault item(s)...")
    # Login and item creation are done via bw CLI (called by the workflow)
    # because the API token format for creating items is complex.
    # This script only handles registration (the hard crypto part).
    print("Done. Use 'bw login' and 'bw create item' to seed items.")


if __name__ == "__main__":
    main()
