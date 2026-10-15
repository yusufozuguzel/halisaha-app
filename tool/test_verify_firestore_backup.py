import copy
import unittest
from verify_firestore_backup import InvalidBackup, validate


def fixture():
    return {"documents": [{
        "name": "projects/demo-depar-recovery/databases/(default)/documents/fixtures/one",
        "fields": {
            "label": {"stringValue": "synthetic"},
            "count": {"integerValue": "9223372036854775807"},
            "when": {"timestampValue": "2026-10-15T09:00:00.123456Z"},
            "items": {"arrayValue": {"values": [{"mapValue": {"fields": {
                "flag": {"booleanValue": True}, "empty": {"nullValue": None}
            }}}]}},
            "bytes": {"bytesValue": "YWJj"},
            "ref": {"referenceValue": "projects/demo-depar-recovery/databases/(default)/documents/fixtures/one"},
            "point": {"geoPointValue": {"latitude": 41.0, "longitude": 29.0}}
        }
    }]}


class SnapshotTests(unittest.TestCase):
    def test_rest_and_mcp_preserve_typed_data(self):
        data = fixture()
        original = copy.deepcopy(data)
        self.assertEqual(validate({"structuredContent": data}, "demo-depar-recovery")["documents"], 1)
        self.assertEqual(data, original)

    def test_incomplete_wrong_project_and_duplicates_rejected(self):
        cases = [dict(fixture(), nextPageToken="more"),
                 {"documents": fixture()["documents"] * 2}, {"isError": True}]
        for data in cases:
            with self.assertRaises(InvalidBackup):
                validate(data, "demo-depar-recovery")
        with self.assertRaises(InvalidBackup):
            validate(fixture(), "wrong-project")

    def test_invalid_value_unions_types_and_nesting_rejected(self):
        for value in ({"stringValue": "x", "integerValue": "1"}, {"integerValue": True},
                      {"integerValue": "9223372036854775808"}, {"bytesValue": "%%%"},
                      {"timestampValue": "2026-99-01T09:00:00Z"},
                      {"geoPointValue": {"latitude": 91, "longitude": 0}},
                      {"arrayValue": {"values": [{"arrayValue": {}}]}}):
            data = fixture()
            data["documents"][0]["fields"]["bad"] = value
            with self.assertRaises(InvalidBackup):
                validate(data, "demo-depar-recovery")


if __name__ == "__main__":
    unittest.main()
