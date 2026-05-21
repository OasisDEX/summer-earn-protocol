"""
DCA keeper bot for DCAStrategyManager.

Polls the DCA subgraph for strategies whose execution window has opened,
re-validates each via the contract's checkUpkeep view, fetches Enso swap
calldata, and broadcasts executeStrategy. Designed as an MVP — single-process,
single-signer, single-chain. Run one instance per chain.

Flow per tick:
  1. GraphQL: ACTIVE strategies with nextTriggerAt <= now and tradesExecuted < maxTrades.
  2. checkUpkeep(config) on-chain — authoritative go/no-go (oracle bounds, etc.).
  3. POST Enso /shortcuts/route → { tx.data }.
  4. executeStrategy(config, ensoData) with serialised nonce + EIP-1559 gas, capped.

Reads config from .env (see .env.example). Run with:
    pip install -r requirements.txt
    python dca_keeper.py
"""

import asyncio
import json
import logging
import os
import random
import sys
import time
from dataclasses import dataclass
from typing import Any, Optional

import aiohttp
from dotenv import load_dotenv
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3 import AsyncHTTPProvider, AsyncWeb3
from web3.exceptions import ContractLogicError, TransactionNotFound

# --- Minimal ABI for the two functions and one view we touch on-chain. ---------
# Keeping the ABI tiny avoids a dependency on the full compiled artifact and
# makes the script self-contained for ops. Argument order MUST match
# IDCAStrategyManager.sol — see StrategyConfig struct at lines 15-31.
DCA_MANAGER_ABI = json.loads(
    """
[
  {
    "type": "function",
    "name": "checkUpkeep",
    "stateMutability": "view",
    "inputs": [
      {"name": "strategyId", "type": "uint256"},
      {
        "name": "config",
        "type": "tuple",
        "components": [
          {"name": "owner",        "type": "address"},
          {"name": "sourceVault",  "type": "address"},
          {"name": "targetVault",  "type": "address"},
          {"name": "inAsset",      "type": "address"},
          {"name": "outAsset",     "type": "address"},
          {"name": "inAssetFeed",  "type": "address"},
          {"name": "outAssetFeed", "type": "address"},
          {"name": "tradeAmount",  "type": "uint256"},
          {"name": "interval",     "type": "uint256"},
          {"name": "slippageBps",  "type": "uint256"},
          {"name": "maxPrice",     "type": "uint256"},
          {"name": "minPrice",     "type": "uint256"},
          {"name": "endDate",      "type": "uint256"},
          {"name": "maxTrades",    "type": "uint256"}
        ]
      }
    ],
    "outputs": [
      {"name": "upkeepNeeded", "type": "bool"},
      {"name": "performData",  "type": "bytes"}
    ]
  },
  {
    "type": "function",
    "name": "executeStrategy",
    "stateMutability": "nonpayable",
    "inputs": [
      {"name": "strategyId", "type": "uint256"},
      {
        "name": "config",
        "type": "tuple",
        "components": [
          {"name": "owner",        "type": "address"},
          {"name": "sourceVault",  "type": "address"},
          {"name": "targetVault",  "type": "address"},
          {"name": "inAsset",      "type": "address"},
          {"name": "outAsset",     "type": "address"},
          {"name": "inAssetFeed",  "type": "address"},
          {"name": "outAssetFeed", "type": "address"},
          {"name": "tradeAmount",  "type": "uint256"},
          {"name": "interval",     "type": "uint256"},
          {"name": "slippageBps",  "type": "uint256"},
          {"name": "maxPrice",     "type": "uint256"},
          {"name": "minPrice",     "type": "uint256"},
          {"name": "endDate",      "type": "uint256"},
          {"name": "maxTrades",    "type": "uint256"}
        ]
      },
      {"name": "ensoData", "type": "bytes"}
    ],
    "outputs": []
  }
]
"""
)

GWEI = 10**9

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s :: %(message)s",
)
log = logging.getLogger("dca-keeper")


@dataclass
class StrategyConfig:
    """Mirror of IDCAStrategyManager.StrategyConfig plus the keeper's own
    `strategyId` cursor.

    `strategyId` lives outside the on-chain StrategyConfig struct (it's the
    mapping key, passed as a separate argument to checkUpkeep/executeStrategy), so
    `as_tuple()` omits it. Field order of as_tuple() must match the contract
    struct in IDCAStrategyManager.sol:15.
    """

    strategyId: int
    owner: str
    sourceVault: str
    targetVault: str
    inAsset: str
    outAsset: str
    inAssetFeed: str
    outAssetFeed: str
    tradeAmount: int
    interval: int
    slippageBps: int
    maxPrice: int
    minPrice: int
    endDate: int
    maxTrades: int

    @classmethod
    def from_subgraph(cls, s: dict[str, Any]) -> "StrategyConfig":
        # The subgraph returns BigInts as decimal strings and Bytes as 0x-hex —
        # both web3.py-friendly once cast.
        def addr(x: str) -> str:
            return AsyncWeb3.to_checksum_address(x)

        return cls(
            strategyId=int(s["strategyId"]),
            owner=addr(s["owner"]["id"]),
            sourceVault=addr(s["sourceVault"]),
            targetVault=addr(s["targetVault"]),
            inAsset=addr(s["inAsset"]),
            outAsset=addr(s["outAsset"]),
            inAssetFeed=addr(s["inAssetFeed"]),
            outAssetFeed=addr(s["outAssetFeed"]),
            tradeAmount=int(s["tradeAmount"]),
            interval=int(s["interval"]),
            slippageBps=int(s["slippageBps"]),
            maxPrice=int(s["maxPrice"]),
            minPrice=int(s["minPrice"]),
            endDate=int(s["endDate"]),
            maxTrades=int(s["maxTrades"]),
        )

    def as_tuple(self) -> tuple:
        return (
            self.owner,
            self.sourceVault,
            self.targetVault,
            self.inAsset,
            self.outAsset,
            self.inAssetFeed,
            self.outAssetFeed,
            self.tradeAmount,
            self.interval,
            self.slippageBps,
            self.maxPrice,
            self.minPrice,
            self.endDate,
            self.maxTrades,
        )


_SUBGRAPH_QUERY = """
query ActiveStrategies($now: BigInt!) {
  strategies(
    first: 1000
    where: {
      status: "ACTIVE"
      nextTriggerAt_lte: $now
      endDate_gt: $now
    }
  ) {
    strategyId
    owner { id }
    sourceVault
    targetVault
    inAsset
    outAsset
    inAssetFeed
    outAssetFeed
    tradeAmount
    interval
    slippageBps
    maxPrice
    minPrice
    endDate
    maxTrades
    tradesExecuted
  }
}
"""


class DCAKeeper:
    """Runs the polling loop and orchestrates per-strategy execution.

    Concurrency model: a bounded semaphore caps parallel executions; a single
    asyncio.Lock serialises the build-sign-broadcast critical section so we
    never reuse a nonce. The in-memory `_next_nonce` is the source of truth
    between broadcasts and gets reconciled from the chain on each refresh.
    """

    def __init__(
        self,
        rpc_url: str,
        chain_id: int,
        manager_address: str,
        private_key: str,
        subgraph_url: str,
        enso_api_url: str,
        enso_api_key: Optional[str],
        poll_interval: int,
        max_concurrent: int,
        max_fee_cap_wei: int,
        priority_fee_wei: int,
        tx_timeout: int,
    ):
        self.chain_id = chain_id
        self.poll_interval = poll_interval
        self.max_fee_cap_wei = max_fee_cap_wei
        self.priority_fee_wei = priority_fee_wei
        self.tx_timeout = tx_timeout
        self.subgraph_url = subgraph_url
        self.enso_api_url = enso_api_url.rstrip("/")
        self.enso_api_key = enso_api_key

        self.w3 = AsyncWeb3(AsyncHTTPProvider(rpc_url))
        self.account: LocalAccount = Account.from_key(private_key)
        self.manager_address = AsyncWeb3.to_checksum_address(manager_address)
        self.manager = self.w3.eth.contract(address=self.manager_address, abi=DCA_MANAGER_ABI)

        self._exec_sema = asyncio.Semaphore(max_concurrent)
        self._nonce_lock = asyncio.Lock()
        self._next_nonce: Optional[int] = None  # initialised on first send

        # One HTTP session per keeper, reused for both subgraph + Enso calls.
        self._session: Optional[aiohttp.ClientSession] = None

    # ------------------------------------------------------------------ lifecycle

    async def __aenter__(self) -> "DCAKeeper":
        self._session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30))
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self._session is not None:
            await self._session.close()

    async def run_forever(self) -> None:
        log.info(
            "Keeper online. signer=%s manager=%s chain=%d poll=%ds",
            self.account.address,
            self.manager_address,
            self.chain_id,
            self.poll_interval,
        )
        while True:
            tick_started = time.monotonic()
            try:
                await self._tick()
            except Exception as e:  # noqa: BLE001 — the loop must never die
                log.exception("Tick failed: %s", e)
            elapsed = time.monotonic() - tick_started
            await asyncio.sleep(max(0.0, self.poll_interval - elapsed))

    # ------------------------------------------------------------------ tick

    async def _tick(self) -> None:
        now = int(time.time())
        strategies = await self._fetch_due_strategies(now)
        log.info("Subgraph returned %d due strategies", len(strategies))
        if not strategies:
            return

        await asyncio.gather(
            *(self._process_one(s) for s in strategies), return_exceptions=False
        )

    async def _process_one(self, raw: dict[str, Any]) -> None:
        # Subgraph filter already enforces nextTriggerAt <= now + status ACTIVE,
        # but tradesExecuted < maxTrades has to be applied client-side because
        # The Graph cannot compare two entity fields against each other.
        try:
            executed = int(raw["tradesExecuted"])
            max_trades = int(raw["maxTrades"])
            if executed >= max_trades:
                return
            cfg = StrategyConfig.from_subgraph(raw)
        except (KeyError, ValueError) as e:
            log.error("Malformed subgraph entry: %s — %s", raw, e)
            return

        async with self._exec_sema:
            await self._maybe_execute(cfg)

    async def _maybe_execute(self, cfg: StrategyConfig) -> None:
        sid = cfg.strategyId

        # Re-validate against the contract — subgraph could be lagging or the
        # oracle could have moved outside the strategy's price guardrails.
        try:
            upkeep_needed, _ = await self.manager.functions.checkUpkeep(
                cfg.strategyId, cfg.as_tuple()
            ).call()
        except ContractLogicError as e:
            log.warning("[%d] checkUpkeep reverted (stale subgraph?): %s", sid, e)
            return
        except Exception as e:  # noqa: BLE001 — RPC flake
            log.warning("[%d] checkUpkeep RPC error: %s — skipping", sid, e)
            return

        if not upkeep_needed:
            log.debug("[%d] checkUpkeep returned false, skipping", sid)
            return

        try:
            enso_data = await self._fetch_enso_route(cfg)
        except Exception as e:  # noqa: BLE001 — already retried internally
            log.error("[%d] Enso routing failed: %s", sid, e)
            return

        await self._broadcast_execute(cfg, enso_data)

    # ------------------------------------------------------------------ subgraph

    async def _fetch_due_strategies(self, now_ts: int) -> list[dict[str, Any]]:
        assert self._session is not None
        payload = {"query": _SUBGRAPH_QUERY, "variables": {"now": str(now_ts)}}
        for attempt in range(4):
            try:
                async with self._session.post(self.subgraph_url, json=payload) as resp:
                    if resp.status == 429 or resp.status >= 500:
                        raise aiohttp.ClientResponseError(
                            resp.request_info, resp.history, status=resp.status, message=resp.reason or ""
                        )
                    resp.raise_for_status()
                    body = await resp.json()
                    if "errors" in body:
                        raise RuntimeError(f"GraphQL errors: {body['errors']}")
                    return body["data"]["strategies"]
            except Exception as e:  # noqa: BLE001
                delay = (2**attempt) + random.random()
                log.warning(
                    "Subgraph fetch failed (attempt %d/4): %s — retrying in %.1fs",
                    attempt + 1,
                    e,
                    delay,
                )
                await asyncio.sleep(delay)
        log.error("Subgraph unavailable after 4 attempts — skipping tick")
        return []

    # ------------------------------------------------------------------ Enso

    async def _fetch_enso_route(self, cfg: StrategyConfig) -> bytes:
        """Ask Enso to route the swap.

        Source/target tokens deliberately use the *fleet vault shares*, not the
        underlying assets. The contract approves Enso for sourceVault shares
        (DCAStrategyManager.sol:248-251) and measures targetVault share gain
        afterwards — so Enso must redeem the source vault and deposit into the
        target vault as part of its shortcut. Setting tokenIn/tokenOut to the
        raw inAsset/outAsset would produce calldata the contract cannot
        satisfy (it doesn't hold raw inAsset at swap time).

        `fromAddress` = `receiver` = the manager, since the manager already
        holds the source shares (pulled via Permit2 just before this call) and
        must hold the target shares when the call returns.
        """
        assert self._session is not None
        params = {
            "chainId": str(self.chain_id),
            "fromAddress": self.manager_address,
            "receiver": self.manager_address,
            "spender": self.manager_address,
            "tokenIn": cfg.sourceVault,
            "tokenOut": cfg.targetVault,
            "amountIn": str(cfg.tradeAmount),
            "slippage": str(cfg.slippageBps),  # Enso slippage is in bps
            "routingStrategy": "router",
        }
        headers = {"accept": "application/json"}
        if self.enso_api_key:
            headers["Authorization"] = f"Bearer {self.enso_api_key}"

        url = f"{self.enso_api_url}/shortcuts/route"

        for attempt in range(5):
            try:
                async with self._session.get(url, params=params, headers=headers) as resp:
                    if resp.status == 429 or resp.status >= 500:
                        raise aiohttp.ClientResponseError(
                            resp.request_info,
                            resp.history,
                            status=resp.status,
                            message=resp.reason or "",
                        )
                    if resp.status >= 400:
                        body = await resp.text()
                        raise RuntimeError(f"Enso {resp.status}: {body[:300]}")
                    data = await resp.json()
                    tx = data.get("tx") or {}
                    calldata_hex = tx.get("data")
                    if not calldata_hex:
                        raise RuntimeError(f"Enso response missing tx.data: {data}")
                    return bytes.fromhex(calldata_hex.removeprefix("0x"))
            except (aiohttp.ClientResponseError, asyncio.TimeoutError) as e:
                delay = (2**attempt) + random.random()
                log.warning(
                    "[%d] Enso retryable error (attempt %d/5): %s — sleeping %.1fs",
                    cfg.strategyId,
                    attempt + 1,
                    e,
                    delay,
                )
                await asyncio.sleep(delay)
        raise RuntimeError("Enso unavailable after 5 attempts")

    # ------------------------------------------------------------------ broadcast

    async def _broadcast_execute(self, cfg: StrategyConfig, enso_data: bytes) -> None:
        sid = cfg.strategyId
        try:
            max_fee, priority_fee = await self._gas_params()
        except Exception as e:  # noqa: BLE001
            log.error("[%d] Failed to compute gas: %s", sid, e)
            return

        if max_fee > self.max_fee_cap_wei:
            log.warning(
                "[%d] maxFeePerGas %.2f gwei would exceed cap %.2f gwei — skipping",
                sid,
                max_fee / GWEI,
                self.max_fee_cap_wei / GWEI,
            )
            return

        # Critical section: lock nonce + build + sign + send. We don't release
        # until the broadcast returns so a concurrent task can't grab the same
        # nonce. After a successful send we increment our in-memory cursor.
        async with self._nonce_lock:
            try:
                nonce = await self._reserve_nonce()
            except Exception as e:  # noqa: BLE001
                log.error("[%d] Failed to reserve nonce: %s", sid, e)
                return

            try:
                fn = self.manager.functions.executeStrategy(
                    cfg.strategyId, cfg.as_tuple(), enso_data
                )
                # build_transaction performs an eth_estimateGas which will
                # revert with the contract's reason string if execution would
                # fail — we surface it and skip rather than broadcast.
                tx = await fn.build_transaction(
                    {
                        "from": self.account.address,
                        "nonce": nonce,
                        "chainId": self.chain_id,
                        "maxFeePerGas": max_fee,
                        "maxPriorityFeePerGas": priority_fee,
                        "type": 2,
                    }
                )
            except ContractLogicError as e:
                log.error("[%d] executeStrategy simulated revert: %s — NOT broadcasting", sid, e)
                # The nonce we "reserved" was never consumed; rewind so we
                # don't leave a permanent gap.
                self._next_nonce = nonce
                return
            except Exception as e:  # noqa: BLE001
                log.error("[%d] build_transaction failed: %s", sid, e)
                self._next_nonce = nonce
                return

            signed = self.account.sign_transaction(tx)
            try:
                tx_hash = await self.w3.eth.send_raw_transaction(signed.raw_transaction)
            except Exception as e:  # noqa: BLE001
                log.error("[%d] send_raw_transaction failed: %s", sid, e)
                # Force a fresh nonce reconciliation next time — we don't know
                # whether the tx hit the mempool.
                self._next_nonce = None
                return

            # Commit the nonce advance only after a successful broadcast.
            self._next_nonce = nonce + 1

        log.info("[%d] executeStrategy broadcast: %s", sid, tx_hash.hex())
        # Don't hold the nonce lock while waiting for inclusion.
        try:
            receipt = await asyncio.wait_for(
                self.w3.eth.wait_for_transaction_receipt(tx_hash),
                timeout=self.tx_timeout,
            )
        except (asyncio.TimeoutError, TransactionNotFound):
            log.warning("[%d] tx %s not mined within %ds — keeper continues",
                        sid, tx_hash.hex(), self.tx_timeout)
            return

        if receipt.status != 1:
            log.error("[%d] tx %s REVERTED on-chain", sid, tx_hash.hex())
        else:
            log.info("[%d] tx %s confirmed in block %d (gas used %d)",
                     sid, tx_hash.hex(), receipt.blockNumber, receipt.gasUsed)

    async def _reserve_nonce(self) -> int:
        # Called while holding _nonce_lock. Lazy-init or recover from `None`
        # marker set after a broadcast error.
        if self._next_nonce is None:
            self._next_nonce = await self.w3.eth.get_transaction_count(
                self.account.address, "pending"
            )
        return self._next_nonce

    async def _gas_params(self) -> tuple[int, int]:
        # EIP-1559: maxFee = baseFee * 2 + tip. The 2× multiplier gives us
        # headroom for one block of base-fee growth; combined with the
        # configured cap we never overpay catastrophically.
        latest = await self.w3.eth.get_block("latest")
        base_fee = latest["baseFeePerGas"]
        max_fee = base_fee * 2 + self.priority_fee_wei
        return max_fee, self.priority_fee_wei


# --------------------------------------------------------------- entrypoint

def _require_env(key: str) -> str:
    v = os.environ.get(key)
    if not v:
        log.error("Missing required env var: %s", key)
        sys.exit(1)
    return v


async def _main() -> None:
    load_dotenv()
    rpc_url = _require_env("RPC_URL")
    chain_id = int(_require_env("CHAIN_ID"))
    manager_address = _require_env("DCA_STRATEGY_MANAGER")
    private_key = _require_env("KEEPER_PRIVATE_KEY")
    subgraph_url = _require_env("SUBGRAPH_URL")
    enso_api_url = os.environ.get("ENSO_API_URL", "https://api.enso.finance/api/v1")
    enso_api_key = os.environ.get("ENSO_API_KEY") or None
    poll_interval = int(os.environ.get("POLL_INTERVAL_SECONDS", "30"))
    max_concurrent = int(os.environ.get("MAX_CONCURRENT_EXECUTIONS", "3"))
    max_fee_cap_wei = int(float(os.environ.get("MAX_FEE_PER_GAS_CAP_GWEI", "100")) * GWEI)
    priority_fee_wei = int(float(os.environ.get("PRIORITY_FEE_GWEI", "1")) * GWEI)
    tx_timeout = int(os.environ.get("TX_CONFIRMATION_TIMEOUT_SECONDS", "180"))

    async with DCAKeeper(
        rpc_url=rpc_url,
        chain_id=chain_id,
        manager_address=manager_address,
        private_key=private_key,
        subgraph_url=subgraph_url,
        enso_api_url=enso_api_url,
        enso_api_key=enso_api_key,
        poll_interval=poll_interval,
        max_concurrent=max_concurrent,
        max_fee_cap_wei=max_fee_cap_wei,
        priority_fee_wei=priority_fee_wei,
        tx_timeout=tx_timeout,
    ) as keeper:
        await keeper.run_forever()


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        log.info("Keeper stopped by user")
