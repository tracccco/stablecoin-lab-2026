#!/usr/bin/env bash
#
# Ex3 — break the peg, with the evidence on screen.
#
#   bash scripts/ex3-display.sh
#
# Starts its own throwaway Anvil, deploys, walks the Ex1 loop once, then runs
# the Ex3 attack: an unauthorized mint reverts, the admin grants MINTER_ROLE to
# an attacker (simulating a leaked key / insider / bribe), and the attacker
# mints 1,000,000 sUSD out of thin air. The final reads show
# totalSupply() >> totalCollateral() — screenshot that block for the submission.
#
# Uses Anvil's unlocked local accounts, so no private key is stored or passed.
set -euo pipefail

export PATH="$HOME/.foundry/bin:$PATH"
command -v forge >/dev/null 2>&1 || { echo "forge not found — install Foundry first (README §1)"; exit 1; }

cd "$(dirname "$0")/.." || exit 1

PORT="${EX3_PORT:-18545}"
RPC="http://127.0.0.1:$PORT"
ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ATTACKER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
USDC=0x5FbDB2315678afecb367f032d93F642f64180aa3
SUSD=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
VAULT=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0

anvil --port "$PORT" >/dev/null 2>&1 &
ANVIL_PID=$!
trap 'kill "$ANVIL_PID" 2>/dev/null' EXIT
sleep 2
# Anvil dies instantly when the port is taken (e.g. a leftover chain) — abort
# instead of talking to someone else's chain.
if ! kill -0 "$ANVIL_PID" 2>/dev/null; then
    echo "port $PORT is already in use — stop the other anvil first" >&2
    exit 1
fi

ANVIL_UNLOCKED_SENDER=$ADMIN forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC" --broadcast --unlocked --sender "$ADMIN" >/dev/null 2>&1

echo "COMP 7810A Assignment Two — Ex3 depeg demonstration (live Anvil, chain 31337)"
echo "MockUSDC $USDC · SimpleStablecoin $SUSD · Vault $VAULT"
echo

echo "== Ex1: deposit 1000 mUSDC through the vault =="
cast send "$USDC" "faucet(address,uint256)" "$ADMIN" 1000000000 --rpc-url "$RPC" --unlocked --from "$ADMIN" >/dev/null 2>&1
cast send "$USDC" "approve(address,uint256)" "$VAULT" 1000000000 --rpc-url "$RPC" --unlocked --from "$ADMIN" >/dev/null 2>&1
cast send "$VAULT" "deposit(uint256)" 1000000000 --rpc-url "$RPC" --unlocked --from "$ADMIN" >/dev/null 2>&1
echo "  totalSupply()      = $(cast call "$SUSD" 'totalSupply()(uint256)' --rpc-url "$RPC")"
echo "  totalCollateral()  = $(cast call "$VAULT" 'totalCollateral()(uint256)' --rpc-url "$RPC")"
echo

echo "== Ex3 step 1: attacker mints without MINTER_ROLE — must revert =="
cast send "$SUSD" "mint(address,uint256)" "$ATTACKER" 1000000000000 \
    --rpc-url "$RPC" --unlocked --from "$ATTACKER" 2>&1 | grep -m1 -oE 'AccessControlUnauthorizedAccount[^"]*' \
    || echo "  reverted (custom error) — as expected"
echo

echo "== Ex3 step 2: admin grants MINTER_ROLE to the attacker =="
cast send "$SUSD" "grantRole(bytes32,address)" "$(cast keccak 'MINTER_ROLE')" "$ATTACKER" \
    --rpc-url "$RPC" --unlocked --from "$ADMIN" 2>&1 | grep -m1 -oE 'status.*'
echo

echo "== Ex3 step 3: attacker mints 1,000,000 sUSD out of thin air =="
cast send "$SUSD" "mint(address,uint256)" "$ATTACKER" 1000000000000 \
    --rpc-url "$RPC" --unlocked --from "$ATTACKER" 2>&1 | grep -m1 -oE 'status.*'
echo

SUPPLY=$(cast call "$SUSD" 'totalSupply()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
COLL=$(cast call "$VAULT" 'totalCollateral()(uint256)' --rpc-url "$RPC" | awk '{print $1}')
echo "== Ex3 step 4: THE DEPEG — read the numbers =="
echo "  totalSupply()      = $SUPPLY"
echo "  totalCollateral()  = $COLL"
echo "  attacker balance   = $(cast call "$SUSD" 'balanceOf(address)(uint256)' "$ATTACKER" --rpc-url "$RPC" | awk '{print $1}')"
echo "  supply / collateral = $((SUPPLY / COLL))"
echo
echo "Supply exceeds collateral by a factor of $((SUPPLY / COLL)) — the peg is gone."
echo "No contract code was changed to do this. Screenshot the block above."
