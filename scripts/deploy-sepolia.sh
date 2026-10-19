#!/usr/bin/env bash
#
# Deploy MockUSDC + SimpleStablecoin + Vault to Sepolia, and optionally verify
# the source on Etherscan.
#
#   bash scripts/deploy-sepolia.sh            # deploy only
#   bash scripts/deploy-sepolia.sh --verify   # verify the existing deployment
#
# The key comes from .env or the environment. Keep .env out of the ZIP.
# The chain ID is checked before any transaction is sent.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

VERIFY=0
if [ "${1:-}" = "--verify" ]; then
    VERIFY=1
elif [ -n "${1:-}" ]; then
    echo "usage: bash scripts/deploy-sepolia.sh [--verify]" >&2
    exit 2
fi

if [ -f .env ]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
fi

: "${SEPOLIA_RPC_URL:?SEPOLIA_RPC_URL is not set}"

# ---------------------------------------------------------------------------
# Safety gate: refuse to broadcast anywhere but Sepolia (chain id 11155111)
# ---------------------------------------------------------------------------
CHAIN_ID=$(cast chain-id --rpc-url "$SEPOLIA_RPC_URL")
if [ "$CHAIN_ID" != "11155111" ]; then
    echo "✗ chain id $CHAIN_ID is not Sepolia (11155111) — refusing to broadcast" >&2
    exit 1
fi

ADDRESS_FILE="submission/sepolia-addresses.json"
if [ "$VERIFY" -eq 0 ]; then
    : "${PRIVATE_KEY:?PRIVATE_KEY is not set — copy .env.example to .env and fill it in}"
    echo "deploying to Sepolia (chain id $CHAIN_ID)"

    # Forge reads the exported key via vm.envUint.
    # Earlier Forge estimates were too low for the Sepolia deployments. The 800%
    # gas multiplier leaves room for the gas used in the successful manual run.
    forge script script/Deploy.s.sol:Deploy --rpc-url "$SEPOLIA_RPC_URL" --broadcast -g 800

    BROADCAST_JSON="broadcast/Deploy.s.sol/11155111/run-latest.json"
    if [ ! -f "$BROADCAST_JSON" ]; then
        echo "✗ broadcast receipt not found at $BROADCAST_JSON" >&2
        exit 1
    fi
    DEPLOYER=$(jq -er '.transactions[0].transaction.from' "$BROADCAST_JSON")
    USDC=$(jq -er '.transactions[] | select(.contractName=="MockUSDC") | .contractAddress' "$BROADCAST_JSON")
    STABLE=$(jq -er '.transactions[] | select(.contractName=="SimpleStablecoin") | .contractAddress' "$BROADCAST_JSON")
    VAULT=$(jq -er '.transactions[] | select(.contractName=="Vault") | .contractAddress' "$BROADCAST_JSON")
    echo "deployer (throwaway test wallet): $DEPLOYER"

    jq -n --arg deployer "$DEPLOYER" --arg usdc "$USDC" --arg stable "$STABLE" --arg vault "$VAULT" \
        '{chainId:11155111, deployer:$deployer, MockUSDC:$usdc, SimpleStablecoin:$stable, Vault:$vault,
          etherscan:{MockUSDC:("https://sepolia.etherscan.io/address/"+$usdc+"#code"),
                     SimpleStablecoin:("https://sepolia.etherscan.io/address/"+$stable+"#code"),
                     Vault:("https://sepolia.etherscan.io/address/"+$vault+"#code")}}' > "$ADDRESS_FILE"
    echo "addresses saved to $ADDRESS_FILE"
else
    : "${ETHERSCAN_API_KEY:?ETHERSCAN_API_KEY is not set — cannot verify}"
    if [ ! -f "$ADDRESS_FILE" ]; then
        echo "✗ $ADDRESS_FILE not found — deploy first" >&2
        exit 1
    fi
    jq -e '(.chainId == 11155111) and
        ([.deployer,.MockUSDC,.SimpleStablecoin,.Vault] |
         all(.[]; type == "string" and test("^0x[0-9a-fA-F]{40}$")))' "$ADDRESS_FILE" >/dev/null
    DEPLOYER=$(jq -r '.deployer' "$ADDRESS_FILE")
    USDC=$(jq -r '.MockUSDC' "$ADDRESS_FILE")
    STABLE=$(jq -r '.SimpleStablecoin' "$ADDRESS_FILE")
    VAULT=$(jq -r '.Vault' "$ADDRESS_FILE")
    echo "verifying existing Sepolia deployment (no transactions sent) ..."
    forge verify-contract "$USDC" src/MockUSDC.sol:MockUSDC \
        --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
    forge verify-contract "$STABLE" src/SimpleStablecoin.sol:SimpleStablecoin \
        --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch \
        --constructor-args "$(cast abi-encode 'constructor(address)' "$DEPLOYER")"
    forge verify-contract "$VAULT" src/Vault.sol:Vault \
        --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch \
        --constructor-args "$(cast abi-encode 'constructor(address,address)' "$USDC" "$STABLE")"
fi

echo "Etherscan links (submit these three):"
echo "  https://sepolia.etherscan.io/address/$USDC#code"
echo "  https://sepolia.etherscan.io/address/$STABLE#code"
echo "  https://sepolia.etherscan.io/address/$VAULT#code"
