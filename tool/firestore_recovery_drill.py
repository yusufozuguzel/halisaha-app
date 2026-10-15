"""Synthetic create-only restore proof. Fixed local demo target; no backup input.

Requires Firebase Firestore emulator at 127.0.0.1:8188. Never accesses
credentials, production hosts, or real user snapshots. Existing fixture data
causes a failure rather than being overwritten. Use a fresh emulator process.
"""
import json
import os
import urllib.error
import urllib.request
from test_verify_firestore_backup import fixture
from verify_firestore_backup import validate

PROJECT = "demo-depar-recovery"
HOST = "127.0.0.1:8188"
BASE = f"http://{HOST}/v1/projects/{PROJECT}/databases/(default)/documents"
# Explicitly disable environment proxy forwarding for local fixture data.
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def request(path, data=None):
    headers = {"Authorization": "Bearer owner", "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(BASE + path, data=body, headers=headers)
    with OPENER.open(req, timeout=10) as response:
        return json.load(response)


def main():
    if os.environ.get("FIRESTORE_EMULATOR_HOST") != HOST:
        raise ValueError("Recovery drill requires its dedicated emulator host")
    data = fixture()
    child = {
        "name": f"projects/{PROJECT}/databases/(default)/documents/fixtures/one/children/two",
        "fields": {"fraction": {"doubleValue": 1.25}, "empty": {"mapValue": {}}}
    }
    data["documents"].append(child)
    validate(data, PROJECT)
    writes = [{"update": doc, "currentDocument": {"exists": False}} for doc in data["documents"]]
    request(":commit", {"writes": writes})
    for doc in data["documents"]:
        suffix = doc["name"].split("/documents", 1)[1]
        actual = request(suffix)
        if actual.get("fields") != doc["fields"]:
            raise ValueError("Typed round-trip mismatch")
    # Retry must fail atomically even if it tries to overwrite one existing
    # document and create another. Confirm neither change was applied.
    changed = {
        "update": {"name": data["documents"][0]["name"], "fields": {"label": {"stringValue": "overwrite"}}},
        "currentDocument": {"exists": False}
    }
    new = {"update": {"name": f"projects/{PROJECT}/databases/(default)/documents/fixtures/three",
                      "fields": {"label": {"stringValue": "must-not-exist"}}},
           "currentDocument": {"exists": False}}
    try:
        request(":commit", {"writes": [new, changed]})
    except urllib.error.HTTPError as error:
        if error.code not in (400, 409):
            raise
    else:
        raise ValueError("Create-only collision unexpectedly succeeded")
    if request("/fixtures/one").get("fields") != data["documents"][0]["fields"]:
        raise ValueError("Collision overwrote data")
    try:
        request("/fixtures/three")
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    else:
        raise ValueError("Failed commit created a partial document")
    print(json.dumps({"passed": True, "syntheticDocuments": 2,
                      "typedRoundTrip": True, "collisionAndAtomicity": True,
                      "productionAccess": False}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError):
        raise SystemExit("Recovery drill failed; no document content printed.") from None
