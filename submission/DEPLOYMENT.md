# Sepolia deployment runbook (Tier 2, 20%)

**Status: DEPLOYED on 2026-10-13.** All three contracts are live on Sepolia (chain id
11155111), post-deploy checks pass (`submission/sepolia-addresses.json`), and the addresses
are listed at the bottom of this file.

Two earlier Forge runs used gas limits that were too low. MockUSDC used 3,397,437 gas on
Sepolia, while the local estimate was about 519,000. The successful run used `cast send
--create` with explicit `--gas-limit` values (see "What actually worked" below).
The contracts deployed by the failed attempts do not exist — only the three addresses below
are real.

## Prerequisites

1. A **fresh throwaway wallet** (created just for this assignment), holding Sepolia test ETH
   from <https://cloud.google.com/application/web3/faucet/ethereum/sepolia>.
2. A Sepolia RPC URL (the default in `.env.example` is the public PublicNode endpoint).
3. Optional but needed for verification: a free API key from <https://etherscan.io/myapikey>.

## Steps

```bash
# 1. Create the env file from the template and fill in the three values.
#    NEVER paste the private key into chat, logs, or the command line history.
cp .env.example .env
#   PRIVATE_KEY=0x...        (throwaway wallet, Sepolia test ETH only)
#   SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
#   ETHERSCAN_API_KEY=...

# 2. Deploy. The script checks that the RPC chain id is 11155111 (Sepolia) BEFORE
#    broadcasting. It reads the public deployer address from the receipt and prints
#    the three contract addresses and Etherscan links.
bash scripts/deploy-sepolia.sh            # or: make deploy-sepolia

# 3. Verify the source of the same three deployed contracts on Etherscan.
bash scripts/deploy-sepolia.sh --verify
```

Without `--verify` the deployment still succeeds and the contracts go on-chain; only the
verification step errors if `ETHERSCAN_API_KEY` is empty. Do not redeploy because of it — run
`scripts/deploy-sepolia.sh --verify` afterwards. That mode reads the saved addresses and sends
no deployment transactions.

## What actually worked (2026-10-13)

```bash
# The scripted path (forge script --broadcast) failed twice on this network:
# forge's gas estimates are ~6x too low for CREATE on Sepolia's current EVM
# (both attempts broadcast deploys that ran out of gas — see receipts below).
# Deploying manually with explicit gas limits succeeded:

cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL" \
  --gas-limit 4000000 --create "$(forge inspect src/MockUSDC.sol:MockUSDC bytecode)"
# gasUsed 3,397,437 — 6.5x the local estimate of ~519k
# Read the contract address from the receipt, then set USDC to that address.

cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL" \
  --gas-limit 9500000 --create "$(forge inspect src/SimpleStablecoin.sol:SimpleStablecoin bytecode)" \
  "$(cast abi-encode 'constructor(address)' "$DEPLOYER" | cut -c3-)"
# Read the contract address from the receipt, then set STABLE to that address.

cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL" \
  --gas-limit 6000000 --create "$(forge inspect src/Vault.sol:Vault bytecode)" \
  "$(cast abi-encode 'constructor(address,address)' "$USDC" "$STABLE" | cut -c3-)"
# Read the contract address from the receipt, then set VAULT to that address.

# grant MINTER_ROLE so the vault can mint
cast send --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL" --gas-limit 500000 \
  "$STABLE" 'grantRole(bytes32,address)' 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 "$VAULT"

# post-deploy checks (all passed)
cast call "$VAULT" 'collateral()(address)'   # == USDC
cast call "$VAULT" 'stable()(address)'       # == STABLE
cast call "$STABLE" 'hasRole(bytes32,address)(bool)' 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 "$VAULT"  # true
```

Failed attempts (for the record — no contracts exist at their addresses):

- forge script run 1 (nonces 0–3) and run 2 (nonces 4–7): all six CREATE transactions
  reverted with `gasUsed == gasLimit` (out of gas). Limits used were 675,333 / 1,248,578 /
  587,889 — forge's local estimates — against on-chain needs of ~3.4M / ~6.4M / ~3M.
  The two `grantRole` calls mined as no-ops against empty addresses.

## Constructor arguments (for manual verification)

| Contract | Constructor |
|---|---|
| `MockUSDC` | *(none)* |
| `SimpleStablecoin` | `(address admin)` — the deployer address |
| `Vault` | `(address collateral, address stable)` — the deployed `MockUSDC` then `SimpleStablecoin` |

Manual fallback:

```bash
forge verify-contract <USDC>    src/MockUSDC.sol:MockUSDC \
  --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch
forge verify-contract <SUSD>    src/SimpleStablecoin.sol:SimpleStablecoin \
  --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch \
  --constructor-args $(cast abi-encode "constructor(address)" <DEPLOYER>)
forge verify-contract <VAULT>   src/Vault.sol:Vault \
  --chain sepolia --etherscan-api-key "$ETHERSCAN_API_KEY" --watch \
  --constructor-args $(cast abi-encode "constructor(address,address)" <USDC> <SUSD>)
```

## After deploying

The script saves `submission/sepolia-addresses.json` with the three addresses and Etherscan
links. Copy those three links into the Moodle submission text box. Fill in the table below —
this is the only record of the real deployment:

| Contract | Address | Etherscan link |
|---|---|---|
| `MockUSDC` | `0x9cfc6ff74644b01357afbc94816ed7dc16700053` | <https://sepolia.etherscan.io/address/0x9cfc6ff74644b01357afbc94816ed7dc16700053#code> |
| `SimpleStablecoin` | `0x9e9247Ba864b7421803A4Bf27A11F71B309e034f` | <https://sepolia.etherscan.io/address/0x9e9247Ba864b7421803A4Bf27A11F71B309e034f#code> |
| `Vault` | `0x4FA94D7e615C4FD84B548Ca8a72b6f30a66B4ceC` | <https://sepolia.etherscan.io/address/0x4FA94D7e615C4FD84B548Ca8a72b6f30a66B4ceC#code> |

Deployer (throwaway test wallet): `0x9b977ba5E443f5d6d8d603Dc912cF9ff1f4469F8`

Verification status (2026-10-13): **verified on Etherscan and Sourcify.**

- Etherscan reports verified source for all three contracts.
- Sourcify v2 lists all three contracts as `exact_match`.

## Safety rules honored by this workflow

- `.env` is in `.gitignore` and is excluded from the submission ZIP by
  `scripts/package-submission.sh`. The packaging script checks the staged files for
  unexpected `.env*` files and key assignments.
- `Deploy.s.sol` reads the key from the environment, and the script does not pass it as a
  process argument. The manual `cast send` commands above do pass it as an argument. Use a
  throwaway test wallet; the key is absent from the submission ZIP.
- The deploy script aborts unless `cast chain-id` returns Sepolia (11155111) — it cannot send
  to mainnet or another production network.
- Only the public deployer address is ever printed.
