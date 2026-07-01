"""AWS Lambda entry point for the DCA keeper (one-shot mode).

EventBridge invokes this handler on a fixed schedule (default every 10 minutes).
Each invocation runs a single keeper pass via ``dca_keeper._main(run_once=True)``
and exits — no long-running loop.

Secrets (RPC URL, signer key, optional Enso key) live in SSM Parameter Store as
``SecureString`` parameters under the prefix in ``KEEPER_SSM_PREFIX`` (e.g.
``/dca-keeper/summer-earn-dca-keeper``). They are fetched + injected into the
environment here; the keeper itself only reads ``os.environ``. Non-secret config
(``CHAIN_ID``, ``DCA_STRATEGY_MANAGER``, ``SUBGRAPH_URL``, ``ENSO_API_URL``,
gas/concurrency tunables, ``LOG_LEVEL``) is supplied as plain Lambda env vars by
Terraform.

``boto3`` ships in the AWS Lambda Python base image; it is also pinned in
``requirements.txt`` for local Docker parity.
"""

import asyncio
import logging
import os

import boto3

from dca_keeper import _main

log = logging.getLogger("dca-keeper-lambda")

# Secret env vars sourced from SSM SecureStrings. Everything else is plain env.
# ENSO_API_KEY is optional (the keeper runs unauthenticated without it).
_SSM_SECRET_KEYS = ("RPC_URL", "KEEPER_PRIVATE_KEY", "ENSO_API_KEY")
_OPTIONAL_SECRET_KEYS = frozenset({"ENSO_API_KEY"})

# Unfilled SecureString sentinel written by the Terraform module
# (infrastructure/modules/lambda_keeper) when a secret var is left empty. Such
# values must NOT be injected: for the optional ENSO key it would otherwise be
# sent as a bogus bearer token, and for a required secret it would mask the
# missing-config error with a nonsense RPC URL / key.
_SSM_PLACEHOLDER = "REPLACE_ME_IN_SSM_CONSOLE"


def _load_secrets_from_ssm() -> None:
    """Fetch the keeper's SecureString secrets and inject them into os.environ.

    No-op when ``KEEPER_SSM_PREFIX`` is unset (e.g. local runs that already
    provide the secrets via the environment / a .env file).
    """
    prefix = os.environ.get("KEEPER_SSM_PREFIX", "").rstrip("/")
    if not prefix:
        log.info("KEEPER_SSM_PREFIX unset — assuming secrets are already in env")
        return

    names = [f"{prefix}/{key}" for key in _SSM_SECRET_KEYS]
    resp = boto3.client("ssm").get_parameters(Names=names, WithDecryption=True)

    invalid_or_placeholder = set()
    for param in resp["Parameters"]:
        key = param["Name"].rsplit("/", 1)[-1]
        value = param["Value"]
        # Empty / unfilled placeholder (see _SSM_PLACEHOLDER) → treat as absent.
        if not value or value == _SSM_PLACEHOLDER:
            invalid_or_placeholder.add(key)
            continue
        os.environ[key] = value

    # Params SSM didn't return, plus the empty/placeholder ones. Clear any stale
    # value a warm Lambda container may still hold from a prior invocation, so the
    # keeper never runs with a stale signer key / RPC URL (and a missing required
    # secret makes _main() fail fast rather than reuse the old one).
    missing = {
        name.rsplit("/", 1)[-1] for name in resp.get("InvalidParameters", [])
    } | invalid_or_placeholder
    for key in missing:
        os.environ.pop(key, None)

    required_missing = missing - _OPTIONAL_SECRET_KEYS
    if required_missing:
        # Surface clearly; _main() will also exit on the missing required vars.
        log.error("Required SSM parameters missing: %s", sorted(required_missing))


def handler(event, context):  # noqa: ANN001 — Lambda signature
    """Run one keeper pass, then return."""
    _load_secrets_from_ssm()
    asyncio.run(_main(run_once=True))
    return {"statusCode": 200, "body": "keeper pass complete"}
