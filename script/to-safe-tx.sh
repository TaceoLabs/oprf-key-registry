#!/usr/bin/env bash
# Run a Foundry script as a dry-run impersonating a Safe, then transform the
# broadcast JSON into Safe Transaction Builder format that can be uploaded via
# https://app.safe.global → Transaction Builder → Load batch.
#
# Usage:
#   ./to-safe-tx.sh <ScriptFile.s.sol> <ChainId> <SafeAddress> [forge-script args...]
#
# Must be run from the `contracts/` directory (the Foundry project root), so
# that Foundry's broadcast/ output lands where we expect it.
#
# Example:
#   OPRF_KEY_REGISTRY_PROXY=0x... OPRF_KEY_ID=42 \
#     script/to-safe-tx.sh script/AbortKeyGen.s.sol 480 0xSafeAddr \
#       --rpc-url "$RPC_URL"

set -euo pipefail

usage() {
    sed -n '2,17p' "$0"
    exit 1
}

[[ $# -ge 3 ]] || usage

SCRIPT_PATH="$1"
CHAIN_ID="$2"
SAFE_ADDR="$3"
shift 3

SCRIPT_BASENAME=$(basename "$SCRIPT_PATH")

# --sender sets msg.sender for vm.broadcast() during simulation. No private key
# is needed because we never pass --broadcast — this is a pure dry-run.
forge script "$SCRIPT_PATH" --sender "$SAFE_ADDR" "$@"

SRC="broadcast/${SCRIPT_BASENAME}/${CHAIN_ID}/dry-run/run-latest.json"
OUT="broadcast/${SCRIPT_BASENAME}/${CHAIN_ID}/safe-tx.json"

if [[ ! -f "$SRC" ]]; then
    echo "error: expected broadcast file not found: $SRC" >&2
    echo "       did the script broadcast any transactions on chain $CHAIN_ID?" >&2
    exit 1
fi

python3 - "$SRC" "$OUT" "$CHAIN_ID" "$SAFE_ADDR" <<'PY'
import json, sys, time

src, out, chain_id, safe = sys.argv[1:]

with open(src) as f:
    data = json.load(f)

transactions = []
creates = []
for entry in data.get("transactions", []):
    tx_type = entry.get("transactionType", "CALL")
    tx = entry["transaction"]
    # Safe Transaction Builder has no way to encode a raw contract deployment
    # (no `to` address). If you need to deploy via a Safe, rewrite the Foundry
    # script to call a deterministic deployer (e.g. CreateX at
    # 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed) instead of emitting CREATE.
    if tx_type in ("CREATE", "CREATE2") or tx.get("to") is None:
        creates.append((tx_type, entry.get("contractName") or "<unknown>"))
        continue
    # Foundry emits value as hex ("0x0"); Safe txBuilder wants a decimal string.
    # int(_, 16) handles full uint256 range.
    value_dec = str(int(tx.get("value") or "0x0", 16))
    transactions.append({
        "to": tx["to"],
        "value": value_dec,
        "data": tx["input"],
        "contractMethod": None,
        "contractInputsValues": None,
    })

if creates:
    print("error: Safe Transaction Builder cannot represent contract deployments.", file=sys.stderr)
    print("       The following transactions have no `to` address:", file=sys.stderr)
    for tx_type, name in creates:
        print(f"         - {tx_type:<8} {name}", file=sys.stderr)
    print("       Rewrite the script to deploy via a factory (e.g. CreateX), or", file=sys.stderr)
    print("       run the deploy from an EOA and only batch the post-deploy calls.", file=sys.stderr)
    sys.exit(2)

if not transactions:
    print("error: no transactions found in broadcast file.", file=sys.stderr)
    sys.exit(1)

safe_batch = {
    "version": "1.0",
    "chainId": chain_id,
    "createdAt": int(time.time() * 1000),
    "meta": {
        "name": "Foundry script batch",
        "description": "",
        "txBuilderVersion": "1.17.0",
        "createdFromSafeAddress": safe,
        "createdFromOwnerAddress": "",
        "checksum": "",
    },
    "transactions": transactions,
}

with open(out, "w") as f:
    json.dump(safe_batch, f, indent=2)

print(f"wrote {out} ({len(transactions)} transaction(s))", file=sys.stderr)
PY
