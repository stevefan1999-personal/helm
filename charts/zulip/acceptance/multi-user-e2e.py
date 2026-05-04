#!/usr/bin/env python3
"""Multi-user Zulip E2E test for a locally deployed chart release."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any

import requests


DEFAULT_URL = "https://192.168.2.190.nip.io"
DEFAULT_ADMIN_EMAIL = "admin@192.168.2.190.nip.io"
DEFAULT_ADMIN_PASSWORD = "zulip-e2e-admin-password"
E2E_PASSWORD = "Zulip-e2e-multi-user-password-2026!"


@dataclass
class ApiUser:
    email: str
    password: str
    full_name: str
    api_key: str = ""
    user_id: int = 0


class ZulipE2E:
    def __init__(
        self,
        *,
        base_url: str,
        namespace: str,
        admin_email: str,
        admin_password: str,
        verify_tls: bool,
        expected_shards: list[int],
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.namespace = namespace
        self.verify_tls = verify_tls
        self.expected_shards = expected_shards
        self.admin = ApiUser(admin_email, admin_password, "E2E Admin")
        self.users = [
            ApiUser("alpha@192.168.2.190.nip.io", E2E_PASSWORD, "E2E Alpha Reviewer"),
            ApiUser("beta@192.168.2.190.nip.io", E2E_PASSWORD, "E2E Beta Reviewer"),
            ApiUser("gamma@192.168.2.190.nip.io", E2E_PASSWORD, "E2E Gamma Reviewer"),
        ]
        self.session = requests.Session()
        self.session.verify = verify_tls

    def run(self, *cmd: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            cmd,
            input=input_text,
            text=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

    def django_pod(self) -> str:
        result = self.run(
            "kubectl",
            "-n",
            self.namespace,
            "get",
            "pod",
            "-l",
            "app.kubernetes.io/component=django",
            "--field-selector=status.phase=Running",
            "-o",
            "jsonpath={.items[0].metadata.name}",
        )
        return result.stdout.strip()

    def manage_shell(self, code: str) -> str:
        pod = self.django_pod()
        result = self.run(
            "kubectl",
            "-n",
            self.namespace,
            "exec",
            pod,
            "-c",
            "django",
            "--",
            "runuser",
            "-u",
            "zulip",
            "--",
            "/home/zulip/deployments/current/manage.py",
            "shell",
            "-c",
            code,
        )
        return result.stdout

    def parse_marked_json(self, output: str, marker: str) -> dict[str, Any]:
        for line in output.splitlines():
            if line.startswith(marker):
                return json.loads(line[len(marker) :])
        raise AssertionError(f"missing {marker!r} marker in manage.py output:\n{output}")

    def manage(self, *args: str) -> str:
        pod = self.django_pod()
        result = self.run(
            "kubectl",
            "-n",
            self.namespace,
            "exec",
            pod,
            "-c",
            "django",
            "--",
            "runuser",
            "-u",
            "zulip",
            "--",
            "/home/zulip/deployments/current/manage.py",
            *args,
        )
        return result.stdout

    def bootstrap_admin(self) -> None:
        code = f"""
from zerver.actions.create_realm import do_create_realm
from zerver.actions.create_user import do_create_user
from zerver.models import Realm, UserProfile

realm = Realm.objects.filter(string_id="").first()
if realm is None:
    realm = do_create_realm(string_id="", name="E2E Zulip")
realm.name = "E2E Zulip"
realm.emails_restricted_to_domains = False
realm.save(update_fields=["name", "emails_restricted_to_domains"])

email = {self.admin.email!r}
password = {self.admin.password!r}
user = UserProfile.objects.filter(delivery_email=email, realm=realm).first()
if user is None:
    user = do_create_user(
        email,
        password,
        realm,
        "E2E Admin",
        role=UserProfile.ROLE_REALM_OWNER,
        realm_creation=True,
        tos_version=None,
        acting_user=None,
    )
user.full_name = "E2E Admin"
user.role = UserProfile.ROLE_REALM_OWNER
user.can_create_users = True
user.is_staff = True
user.is_active = True
user.tos_version = None
user.set_password(password)
user.save()
print("admin bootstrap ok", user.id)
"""
        self.manage_shell(code)

    def ensure_user_passwords(self) -> None:
        users = [(u.email, u.password, u.full_name) for u in self.users]
        code = f"""
from zerver.actions.create_user import do_create_user
from zerver.models import Realm, UserProfile

realm = Realm.objects.get(string_id="")
users = {users!r}
for email, password, full_name in users:
    user = UserProfile.objects.filter(delivery_email=email, realm=realm).first()
    if user is None:
        user = do_create_user(
            email,
            password,
            realm,
            full_name,
            role=UserProfile.ROLE_MEMBER,
            tos_version=None,
            acting_user=None,
        )
    user.full_name = full_name
    user.role = UserProfile.ROLE_MEMBER
    user.is_active = True
    user.tos_version = None
    user.set_password(password)
    user.save()
    print("user ready", user.id, email)
"""
        self.manage_shell(code)

    def fetch_api_key(self, user: ApiUser) -> None:
        data = {"username": user.email, "password": user.password}
        response = self.session.post(f"{self.base_url}/api/v1/fetch_api_key", data=data, timeout=30)
        payload = self.expect_json(response, "fetch_api_key")
        user.api_key = payload["api_key"]
        user.user_id = int(payload["user_id"])

    def api(
        self,
        user: ApiUser,
        method: str,
        path: str,
        *,
        data: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
        allow_error: bool = False,
    ) -> dict[str, Any]:
        response = self.session.request(
            method,
            f"{self.base_url}/api/v1{path}",
            auth=(user.email, user.api_key),
            data=data,
            params=params,
            timeout=45,
        )
        payload = self.expect_json(response, f"{method} {path}", allow_error=allow_error)
        if not allow_error and payload.get("result") != "success":
            raise AssertionError(f"{method} {path} failed: {payload}")
        return payload

    def expect_json(
        self, response: requests.Response, context: str, *, allow_error: bool = False
    ) -> dict[str, Any]:
        try:
            payload = response.json()
        except ValueError as error:
            raise AssertionError(
                f"{context}: expected JSON, got {response.status_code} {response.text[:500]}"
            ) from error
        if response.status_code >= 400 and not allow_error:
            raise AssertionError(f"{context}: HTTP {response.status_code}: {payload}")
        return payload

    def create_users_via_api(self) -> None:
        for user in self.users:
            payload = self.api(
                self.admin,
                "POST",
                "/users",
                data={
                    "email": user.email,
                    "password": user.password,
                    "full_name": user.full_name,
                },
                allow_error=True,
            )
            if payload.get("result") == "success":
                continue
            msg = payload.get("msg", "")
            if "already" not in msg.lower() and "exists" not in msg.lower():
                raise AssertionError(f"create user {user.email} failed: {payload}")
        self.ensure_user_passwords()
        for user in self.users:
            self.fetch_api_key(user)

    def refresh_user_ids(self) -> None:
        payload = self.api(self.admin, "GET", "/users")
        by_delivery_email = {
            member.get("delivery_email"): member["user_id"]
            for member in payload["members"]
            if member.get("delivery_email")
        }
        for user in [self.admin, *self.users]:
            if user.email in by_delivery_email:
                user.user_id = int(by_delivery_email[user.email])
        missing = [user.email for user in self.users if not user.user_id]
        if missing:
            raise AssertionError(f"missing users from /users: {missing}")

    def create_channels(self) -> list[str]:
        channel_names = ["e2e-review", "e2e-war-room"]
        subscriptions = [
            {"name": channel_names[0], "description": "Multi-user review E2E channel"},
            {"name": channel_names[1], "description": "Multi-user incident E2E channel"},
        ]
        principals = [user.user_id for user in [self.admin, *self.users]]
        payload = self.api(
            self.admin,
            "POST",
            "/users/me/subscriptions",
            data={
                "subscriptions": json.dumps(subscriptions),
                "principals": json.dumps(principals),
                "announce": json.dumps(False),
                "send_new_subscription_messages": json.dumps(False),
                "history_public_to_subscribers": json.dumps(True),
            },
        )
        subscribed = payload.get("subscribed", {})
        already = payload.get("already_subscribed", {})
        if not subscribed and not already:
            raise AssertionError(f"channel subscription produced no result: {payload}")
        return channel_names

    def register_events(self, user: ApiUser) -> str:
        payload = self.api(
            user,
            "POST",
            "/register",
            data={
                "event_types": json.dumps(["message", "reaction", "update_message_flags"]),
                "client_gravatar": json.dumps(True),
                "slim_presence": json.dumps(True),
            },
        )
        queue_id = payload.get("queue_id")
        if not queue_id:
            raise AssertionError(f"missing queue_id for {user.email}: {payload}")
        return str(queue_id)

    def verify_sharding(self) -> dict[str, Any]:
        if not self.expected_shards:
            return {}
        emails = [user.email for user in [self.admin, *self.users]]
        marker = "ZULIP_E2E_SHARDS="
        code = f"""
import json
from zerver.models import Realm, UserProfile
from zerver.tornado.sharding import get_realm_tornado_ports, get_user_tornado_port

realm = Realm.objects.get(string_id="")
users = UserProfile.objects.filter(delivery_email__in={emails!r}, realm=realm).order_by("id")
data = {{
    "realm_host": realm.host,
    "realm_ports": get_realm_tornado_ports(realm),
    "users": {{
        user.delivery_email: {{
            "id": user.id,
            "tornado_port": get_user_tornado_port(user),
        }}
        for user in users
    }},
}}
print({marker!r} + json.dumps(data, sort_keys=True))
"""
        data = self.parse_marked_json(self.manage_shell(code), marker)
        realm_ports = [int(port) for port in data["realm_ports"]]
        if realm_ports != self.expected_shards:
            raise AssertionError(
                f"realm {data['realm_host']} uses Tornado ports {realm_ports}, "
                f"expected {self.expected_shards}"
            )

        actual_ports = {
            email: int(details["tornado_port"]) for email, details in data["users"].items()
        }
        expected_by_user = {
            user.email: self.expected_shards[user.user_id % len(self.expected_shards)]
            for user in [self.admin, *self.users]
        }
        if actual_ports != expected_by_user:
            raise AssertionError(
                f"unexpected per-user Tornado shard mapping: {actual_ports}, "
                f"expected {expected_by_user}"
            )

        covered_ports = sorted(set(actual_ports.values()))
        if covered_ports != sorted(self.expected_shards):
            raise AssertionError(
                f"E2E users cover Tornado shards {covered_ports}, "
                f"expected coverage of {sorted(self.expected_shards)}"
            )

        return {
            "realm_host": data["realm_host"],
            "realm_ports": realm_ports,
            "users": data["users"],
        }

    def send_channel_message(self, user: ApiUser, channel: str, topic: str, content: str) -> int:
        payload = self.api(
            user,
            "POST",
            "/messages",
            data={"type": "stream", "to": channel, "topic": topic, "content": content},
        )
        return int(payload["id"])

    def send_direct_message(self, user: ApiUser, recipients: list[ApiUser], content: str) -> int:
        payload = self.api(
            user,
            "POST",
            "/messages",
            data={
                "type": "private",
                "to": json.dumps([recipient.user_id for recipient in recipients]),
                "content": content,
            },
        )
        return int(payload["id"])

    def get_messages(self, user: ApiUser, message_ids: list[int]) -> list[dict[str, Any]]:
        payload = self.api(
            user,
            "GET",
            "/messages",
            params={"message_ids": json.dumps(message_ids), "apply_markdown": json.dumps(False)},
        )
        messages = payload.get("messages", [])
        found = {message["id"] for message in messages}
        missing = set(message_ids) - found
        if missing:
            raise AssertionError(f"{user.email} could not fetch messages {sorted(missing)}")
        return messages

    def wait_for_message_event(self, user: ApiUser, queue_id: str, message_id: int) -> None:
        last_event_id = -1
        deadline = time.time() + 20
        while time.time() < deadline:
            payload = self.api(
                user,
                "GET",
                "/events",
                params={
                    "queue_id": queue_id,
                    "last_event_id": last_event_id,
                    "dont_block": json.dumps(True),
                },
            )
            for event in payload.get("events", []):
                last_event_id = max(last_event_id, int(event.get("id", last_event_id)))
                message = event.get("message") or {}
                if event.get("type") == "message" and message.get("id") == message_id:
                    return
            time.sleep(0.5)
        raise AssertionError(f"{user.email} did not receive message event {message_id}")

    def review_messages(self, alpha_msg: int, beta_msg: int, dm_msg: int) -> None:
        beta = self.users[1]
        gamma = self.users[2]
        alpha = self.users[0]

        self.api(beta, "POST", f"/messages/{alpha_msg}/reactions", data={"emoji_name": "octopus"})
        self.api(gamma, "POST", f"/messages/{alpha_msg}/reactions", data={"emoji_name": "octopus"})
        self.api(alpha, "POST", f"/messages/{beta_msg}/reactions", data={"emoji_name": "thumbs_up"})

        for user in [beta, gamma]:
            self.api(
                user,
                "POST",
                "/messages/flags",
                data={"messages": json.dumps([alpha_msg, beta_msg, dm_msg]), "op": "add", "flag": "read"},
            )

        messages = self.get_messages(alpha, [alpha_msg, beta_msg, dm_msg])
        alpha_message = next(message for message in messages if message["id"] == alpha_msg)
        reactions = alpha_message.get("reactions", [])
        reviewers = {reaction["user_id"] for reaction in reactions if reaction["emoji_name"] == "octopus"}
        expected_reviewers = {beta.user_id, gamma.user_id}
        if reviewers != expected_reviewers:
            raise AssertionError(f"unexpected reviewers for message {alpha_msg}: {reactions}")

        receipts = self.api(alpha, "GET", f"/messages/{alpha_msg}/read_receipts")
        reader_ids = set(receipts.get("user_ids", []))
        if not expected_reviewers.issubset(reader_ids):
            raise AssertionError(f"read receipt missing reviewers: {receipts}")

    def refresh_analytics(self) -> None:
        self.manage("update_analytics_counts", "--verbose")
        for chart_name in [
            "number_of_humans",
            "messages_sent_by_message_type",
            "messages_sent_by_client",
            "messages_read_over_time",
        ]:
            payload = self.api(
                self.admin,
                "GET",
                "/analytics/chart_data",
                params={"chart_name": chart_name, "min_length": 10},
            )
            if "end_times" not in payload:
                raise AssertionError(f"analytics chart {chart_name} returned no data: {payload}")

    def execute(self) -> dict[str, Any]:
        self.bootstrap_admin()
        self.fetch_api_key(self.admin)
        self.create_users_via_api()
        self.refresh_user_ids()
        sharding = self.verify_sharding()
        channels = self.create_channels()

        alpha, beta, gamma = self.users
        queues = {user.email: self.register_events(user) for user in [alpha, beta, gamma]}
        topic = "socats and charts"
        alpha_msg = self.send_channel_message(
            alpha,
            channels[0],
            topic,
            "Alpha proposes the chart change for review.",
        )
        beta_msg = self.send_channel_message(
            beta,
            channels[0],
            topic,
            "Beta reviews the chart change and confirms the service path.",
        )
        gamma_msg = self.send_channel_message(
            gamma,
            channels[1],
            "scale check",
            "Gamma confirms the scaled workers can see the incident channel.",
        )
        dm_msg = self.send_direct_message(
            alpha,
            [beta, gamma],
            "Please review the E2E result before we call it done.",
        )

        self.wait_for_message_event(beta, queues[beta.email], alpha_msg)
        self.wait_for_message_event(gamma, queues[gamma.email], alpha_msg)
        self.wait_for_message_event(alpha, queues[alpha.email], beta_msg)

        for user in [alpha, beta, gamma]:
            self.get_messages(user, [alpha_msg, beta_msg, gamma_msg, dm_msg])

        self.review_messages(alpha_msg, beta_msg, dm_msg)
        self.refresh_analytics()

        return {
            "channels": channels,
            "users": {user.email: user.user_id for user in [self.admin, *self.users]},
            "sharding": sharding,
            "messages": {
                "alpha_channel_message": alpha_msg,
                "beta_channel_message": beta_msg,
                "gamma_channel_message": gamma_msg,
                "alpha_group_dm": dm_msg,
            },
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=os.environ.get("ZULIP_E2E_URL", DEFAULT_URL))
    parser.add_argument("--namespace", default=os.environ.get("NS", "zulip-e2e"))
    parser.add_argument("--admin-email", default=os.environ.get("ZULIP_E2E_ADMIN_EMAIL", DEFAULT_ADMIN_EMAIL))
    parser.add_argument(
        "--admin-password",
        default=os.environ.get("ZULIP_E2E_ADMIN_PASSWORD", DEFAULT_ADMIN_PASSWORD),
    )
    parser.add_argument("--verify-tls", action="store_true", help="Verify the test endpoint TLS certificate")
    parser.add_argument(
        "--expect-shards",
        default=os.environ.get("ZULIP_E2E_EXPECT_SHARDS", ""),
        help="Comma-separated Tornado ports that the root realm should shard across.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.verify_tls:
        requests.packages.urllib3.disable_warnings()
    test = ZulipE2E(
        base_url=args.url,
        namespace=args.namespace,
        admin_email=args.admin_email,
        admin_password=args.admin_password,
        verify_tls=args.verify_tls,
        expected_shards=[int(port) for port in args.expect_shards.split(",") if port],
    )
    result = test.execute()
    print(json.dumps({"result": "success", **result}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
