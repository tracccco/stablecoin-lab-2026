#!/usr/bin/env bash
# Demonstrate Ex1 and Ex3 only on an already-running local Anvil instance.
set -euo pipefail
cd "$(dirname "$0")/.."
RPC="${RPC:-http://127.0.0.1:18545}"
[[ "$RPC" == http://127.0.0.1:* ]] || { echo 'Local loopback RPC required'; exit 1; }
[[ "$(cast chain-id --rpc-url "$RPC")" == 31337 ]] || { echo 'Anvil chain 31337 required'; exit 1; }
mkdir -p submission
ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_UNLOCKED_SENDER=$ADMIN forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$RPC" --broadcast --unlocked --sender "$ADMIN" > /tmp/stablecoin-local-deploy.txt 2>&1
export USDC SUSD VAULT RPC
USDC=$(awk '/MockUSDC         :/ {print $NF}' /tmp/stablecoin-local-deploy.txt | tail -1)
SUSD=$(awk '/SimpleStablecoin :/ {print $NF}' /tmp/stablecoin-local-deploy.txt | tail -1)
VAULT=$(awk '/Vault            :/ {print $NF}' /tmp/stablecoin-local-deploy.txt | tail -1)
[[ -n "$USDC" && -n "$SUSD" && -n "$VAULT" ]]
ATTACKER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
send() { cast send "$@" --rpc-url "$RPC" --unlocked --from "$ADMIN" >/dev/null; }
call() { cast call "$@" --rpc-url "$RPC"; }
{
  echo 'COMP 7810A Assignment Two — live Anvil Ex1 / Ex3'
  echo "RPC: $RPC; chain ID: $(cast chain-id --rpc-url "$RPC")"
  echo "MockUSDC: $USDC"
  echo "SimpleStablecoin: $SUSD"
  echo "Vault: $VAULT"
  echo 'Both mUSDC and sUSD use 6 decimals; values below are raw units.'
  send "$USDC" 'faucet(address,uint256)' "$ADMIN" 1000000000
  send "$USDC" 'approve(address,uint256)' "$VAULT" 1000000000
  send "$VAULT" 'deposit(uint256)' 1000000000
  echo 'Ex1: deposit 1,000 mUSDC'
  echo "totalSupply(): $(call "$SUSD" 'totalSupply()(uint256)')"
  echo "totalCollateral(): $(call "$VAULT" 'totalCollateral()(uint256)')"
  echo "balanceOf(depositor): $(call "$SUSD" 'balanceOf(address)(uint256)' "$ADMIN")"
  send "$VAULT" 'redeem(uint256)' 1000000000
  echo 'Ex1: redeem all, supply and collateral return to zero'
  echo "totalSupply(): $(call "$SUSD" 'totalSupply()(uint256)')"
  echo "totalCollateral(): $(call "$VAULT" 'totalCollateral()(uint256)')"
  send "$USDC" 'approve(address,uint256)' "$VAULT" 1000000000
  send "$VAULT" 'deposit(uint256)' 1000000000
  echo 'Ex3: unauthorized attacker mint must revert'
  if cast send "$SUSD" 'mint(address,uint256)' "$ATTACKER" 1000000000000 --rpc-url "$RPC" --unlocked --from "$ATTACKER" >/tmp/stablecoin-unauthorized.txt 2>&1; then
    echo 'ERROR: unauthorized mint unexpectedly succeeded'; exit 1
  fi
  cat /tmp/stablecoin-unauthorized.txt
  ROLE=$(cast keccak MINTER_ROLE)
  send "$SUSD" 'grantRole(bytes32,address)' "$ROLE" "$ATTACKER"
  echo 'Admin granted attacker MINTER_ROLE (local compromise simulation).'
  cast send "$SUSD" 'mint(address,uint256)' "$ATTACKER" 1000000000000 --rpc-url "$RPC" --unlocked --from "$ATTACKER" >/tmp/stablecoin-attack-receipt.txt
  cat /tmp/stablecoin-attack-receipt.txt
  echo 'Ex3: after minting 1,000,000 unbacked sUSD'
  echo "totalSupply(): $(call "$SUSD" 'totalSupply()(uint256)')"
  echo "totalCollateral(): $(call "$VAULT" 'totalCollateral()(uint256)')"
  echo "attacker sUSD: $(call "$SUSD" 'balanceOf(address)(uint256)' "$ATTACKER")"
  echo 'Supply / collateral = 1001. This proves unbacked issuance; no market quote is asserted.'
} > submission/ex3-transcript.txt 2>&1
ruby -rjson -e 'File.write("submission/local-addresses.json", JSON.pretty_generate(ENV.to_h.select{|k,v| %w[USDC SUSD VAULT RPC].include?(k)}))'
echo 'Ex1 round trip and Ex3 privileged issuance reproduced; see submission/ex3-transcript.txt'
