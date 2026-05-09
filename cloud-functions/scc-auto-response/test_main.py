"""Unit tests for SCC auto-response Cloud Function."""

import json
import os
import unittest
from unittest.mock import MagicMock, patch

os.environ.setdefault("PROJECT_ID", "test-project")
os.environ.setdefault("ORG_ID", "123456789")
os.environ.setdefault("DRY_RUN", "true")
os.environ.setdefault("SLACK_WEBHOOK_URL", "")

import main  # noqa: E402 — must import after env vars are set


def _make_cloud_event(finding: dict) -> MagicMock:
    import base64
    payload = json.dumps({"finding": finding}).encode()
    event = MagicMock()
    event.data = {"message": {"data": base64.b64encode(payload).decode()}}
    return event


class TestHandleFinding(unittest.TestCase):

    def test_unknown_category_does_not_raise(self):
        event = _make_cloud_event({
            "category": "UNKNOWN_CATEGORY",
            "resourceName": "//compute.googleapis.com/projects/test/zones/us-central1-a/instances/vm1",
            "severity": "LOW",
            "name": "organizations/123/sources/456/findings/789",
        })
        main.handle_finding(event)  # should not raise

    def test_public_bucket_dry_run_does_not_call_storage(self):
        event = _make_cloud_event({
            "category": "PUBLIC_BUCKET_ACL",
            "resourceName": "//storage.googleapis.com/projects/_/buckets/my-bucket",
            "severity": "HIGH",
            "name": "organizations/123/sources/456/findings/abc",
        })
        with patch("main.storage.Client") as mock_storage:
            main.handle_finding(event)
            mock_storage.assert_not_called()  # DRY_RUN=true — no API calls

    def test_open_firewall_dry_run_does_not_call_compute(self):
        event = _make_cloud_event({
            "category": "OPEN_FIREWALL",
            "resourceName": "//compute.googleapis.com/projects/test/global/firewalls/allow-all",
            "severity": "HIGH",
            "name": "organizations/123/sources/456/findings/def",
        })
        with patch("main.compute_v1.FirewallsClient") as mock_compute:
            main.handle_finding(event)
            mock_compute.assert_not_called()

    def test_crypto_miner_dry_run_does_not_stop_instance(self):
        event = _make_cloud_event({
            "category": "CRYPTO_MINER_DETECTED",
            "resourceName": "//compute.googleapis.com/projects/test/zones/us-central1-a/instances/miner-vm",
            "severity": "CRITICAL",
            "name": "organizations/123/sources/456/findings/ghi",
        })
        with patch("main.compute_v1.InstancesClient") as mock_compute:
            main.handle_finding(event)
            mock_compute.assert_not_called()

    def test_malformed_message_does_not_raise(self):
        event = MagicMock()
        event.data = {"message": {"data": "not-base64!!"}}
        main.handle_finding(event)  # should log error and return, not raise

    def test_notify_slack_skips_when_no_url(self):
        with patch("main.requests.post") as mock_post:
            main._notify_slack("TEST", "LOW", "//resource", "msg")
            mock_post.assert_not_called()

    def test_notify_slack_posts_when_url_set(self):
        with patch.object(main, "SLACK_WEBHOOK_URL", "https://hooks.slack.com/test"), \
             patch("main.requests.post") as mock_post:
            mock_post.return_value = MagicMock(raise_for_status=MagicMock())
            main._notify_slack("TEST", "CRITICAL", "//resource", "msg")
            mock_post.assert_called_once()


if __name__ == "__main__":
    unittest.main()
