"""Read-only validation of portable Firestore REST/MCP snapshots.

Never uploads data, obtains credentials, or prints document names/values.
This validates the supplied snapshot, not completeness of the live database.
"""
import argparse
import base64
import hashlib
import json
import math
import re
from datetime import datetime
from pathlib import Path


class InvalidBackup(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InvalidBackup(message)


def document_path(name, project):
    prefix = f"projects/{project}/databases/(default)/documents/"
    require(isinstance(name, str) and name.startswith(prefix), "Wrong project/database or document name")
    parts = name[len(prefix):].split("/")
    require(len(parts) >= 2 and len(parts) % 2 == 0 and all(
        p and p not in (".", "..") and len(p.encode()) <= 1500 for p in parts
    ), "Invalid document path")
    return parts


def timestamp(value):
    require(isinstance(value, str) and bool(re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})", value
    )), "Invalid timestamp")
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise InvalidBackup("Invalid timestamp") from None


def fields_valid(fields, project, depth):
    require(isinstance(fields, dict), "Invalid fields map")
    for key, value in fields.items():
        require(isinstance(key, str) and 0 < len(key.encode()) <= 1500, "Invalid field name")
        value_valid(value, project, depth)


def value_valid(value, project, depth=0, in_array=False):
    require(depth <= 20 and isinstance(value, dict) and len(value) == 1, "Invalid typed value or nesting")
    kind, data = next(iter(value.items()))
    if kind == "nullValue":
        require(data is None, "Invalid null")
    elif kind == "booleanValue":
        require(type(data) is bool, "Invalid boolean")
    elif kind == "integerValue":
        require(isinstance(data, str) and bool(re.fullmatch(r"-?\d+", data))
                and -(2**63) <= int(data) < 2**63, "Invalid integer")
    elif kind == "doubleValue":
        require((type(data) in (int, float) and math.isfinite(data))
                or data in ("NaN", "Infinity", "-Infinity"), "Invalid double")
    elif kind == "timestampValue":
        timestamp(data)
    elif kind == "stringValue":
        require(isinstance(data, str) and len(data.encode()) <= 1048487, "Invalid string")
    elif kind == "bytesValue":
        require(isinstance(data, str), "Invalid bytes")
        try:
            decoded = base64.b64decode(data, validate=True)
        except ValueError:
            raise InvalidBackup("Invalid base64 bytes") from None
        require(len(decoded) <= 1048487, "Bytes too large")
    elif kind == "referenceValue":
        # Cross-project references are valid Firestore values; they are preserved.
        require(isinstance(data, str) and bool(re.fullmatch(
            r"projects/[^/]+/databases/[^/]+/documents/(?:[^/]+/)*[^/]+", data
        )), "Invalid reference")
        require(len(data.split("/documents/", 1)[1].split("/")) % 2 == 0, "Invalid reference path")
    elif kind == "geoPointValue":
        require(isinstance(data, dict) and set(data) == {"latitude", "longitude"}, "Invalid geo point")
        for key, bound in (("latitude", 90), ("longitude", 180)):
            require(type(data[key]) in (int, float) and math.isfinite(data[key])
                    and abs(data[key]) <= bound, "Invalid geo coordinate")
    elif kind == "arrayValue":
        require(not in_array and isinstance(data, dict) and set(data) <= {"values"}, "Invalid array")
        require(isinstance(data.get("values", []), list), "Invalid array values")
        for child in data.get("values", []):
            value_valid(child, project, depth + 1, in_array=True)
    elif kind == "mapValue":
        require(isinstance(data, dict) and set(data) <= {"fields"}, "Invalid map")
        fields_valid(data.get("fields", {}), project, depth + 1)
    else:
        raise InvalidBackup("Unknown Firestore value type")


def extract(payload):
    require(isinstance(payload, dict) and not payload.get("isError"), "Invalid/error snapshot")
    if "structuredContent" in payload:
        return extract(payload["structuredContent"])
    if "documents" in payload:
        return payload
    content = payload.get("content", [])
    require(isinstance(content, list), "Invalid MCP content")
    texts = [x.get("text") for x in content if isinstance(x, dict) and x.get("type") == "text"]
    require(len(texts) == 1, "Snapshot document payload missing")
    return extract(json.loads(texts[0]))


def validate(payload, project):
    require(bool(re.fullmatch(r"[a-z][a-z0-9-]{4,62}", project)), "Invalid expected project")
    data = extract(payload)
    require(not data.get("nextPageToken"), "Incomplete paginated snapshot")
    documents = data.get("documents")
    require(isinstance(documents, list) and bool(documents), "Empty/missing documents")
    seen = set()
    collections = set()
    for doc in documents:
        require(isinstance(doc, dict), "Invalid document")
        parts = document_path(doc.get("name"), project)
        require(doc["name"] not in seen, "Duplicate document")
        seen.add(doc["name"])
        collections.add(parts[0])
        fields_valid(doc.get("fields", {}), project, 0)
        for key in ("createTime", "updateTime"):
            if key in doc:
                timestamp(doc[key])
    return {"documents": len(documents), "rootCollections": len(collections), "project": project}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--project", required=True)
    parser.add_argument("--sha256", help="Previously recorded checksum; mismatch fails")
    args = parser.parse_args()
    try:
        raw = args.snapshot.read_bytes()
        digest = hashlib.sha256(raw).hexdigest().upper()
        require(not args.sha256 or args.sha256.upper() == digest, "Checksum mismatch")
        result = validate(json.loads(raw.decode("utf-8-sig")), args.project)
        print(json.dumps({"valid": True, **result, "sha256": digest}))
    except (OSError, ValueError, TypeError, KeyError, OverflowError):
        parser.exit(1, "Snapshot validation failed; no document content printed.\n")


if __name__ == "__main__":
    main()
