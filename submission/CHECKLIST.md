# Assignment checklist and verification record

Project: stablecoin-lab-2026-main · ZIP rechecked: 2026-10-14 (Asia/Shanghai).

| Requirement | Files / evidence | Verification result |
|---|---|---|
| Ex0 | Makefile, scripts/doctor.sh, submission/final-doctor.txt | `make doctor` 6/6 ✓; `make test` 7 passed ✓ |
| Ex1 | submission/ex1-transcript.txt | faucet → approve → deposit → redeem on live Anvil; supply and collateral move together ✓ |
| Ex2 | test/exercises/01_LoopTasks.t.sol | both `test_Ex2_*` pass ✓ |
| Ex3 | submission/ex3.png + ex3-transcript.txt + scripts/ex3-display.sh | live Anvil: unauthorized mint reverted, role granted, 1e12 sUSD minted; totalSupply 1.001e12 vs totalCollateral 1e9 (×1001) ✓ |
| Ex4 | test/exercises/01_LoopTasks.t.sol | all five `test_Ex4_*` pass ✓ |
| Ex5 | src/exercises/OverCollateralizedVault.sol | all 4 TODOs implemented; 03_* 10/10 and 04_* 15/15 pass ✓ |
| Ex6 | test/exercises/02_InvariantTasks.t.sol | handler `redeem` implemented; both invariants pass at 256 runs × 100 depth = 25,600 calls, 0 reverts, 0 discards ✓ |
| Ex7 (Tier 3, optional) | test/challenges/Unstoppable.t.sol | solved; `make challenge` 2/2 ✓ |
| Threat model | STUDENT-QUESTIONS.md | A1–D2 all answered within the 150–300 word limit; section E table complete + extra scenario ✓ |
| Architecture | README.md | Mermaid diagram of core loop + Ex5 system; flows and authorization boundaries documented ✓ |
| Sepolia deployment (Tier 2) | submission/sepolia-addresses.json, submission/DEPLOYMENT.md | deployed 2026-10-13; post-deploy checks pass (collateral/stable wiring, MINTER_ROLE granted, code present) ✓ |
| Etherscan verification | `bash scripts/deploy-sepolia.sh --verify`, Sourcify v2 API | all three pages show verified source; Sourcify lists all three as exact matches ✓ |
| Deployment docs | scripts/deploy-sepolia.sh, submission/DEPLOYMENT.md | runbook updated with the real addresses and the gas-estimation workaround ✓ |
| Package | scripts/package-submission.sh, submission/package-check.txt | ZIP built, `unzip -t` clean, secret scan clean ✓ |

## Final test commands and results (GNU make 4.3 via /tmp/stablecoin-tools)

| Command | Result |
|---|---|
| `make doctor` | 6 passed, 0 failed — ready for class |
| `make test` | 7 passed, 0 failed |
| `make exercise` | 34 passed, 0 failed (Ex2/4/5/6 suites + edge cases) |
| `make challenge` | 2 passed, 0 failed |
| `forge test --match-path test/exercises/02_InvariantTasks.t.sol -vv --invariant-depth 100` (256 runs) | 25,600 calls, 0 reverts, 0 discards; both invariants hold |

Full logs: submission/final-doctor.txt, submission/final-tests.txt.

## Machine notes

- `/usr/bin/make` and `/usr/bin/git` fail on this machine because Apple Command Line
  Tools are missing (`xcode-select` note). The fix is `xcode-select --install`; until then,
  GNU Make 4.3 from /tmp/stablecoin-tools was used for `make`-based verification.
  forge/cast/anvil 1.8.4 are unaffected.
- Sepolia deployment **is done** (2026-10-13): MockUSDC
  `0x9cfc6ff74644b01357afbc94816ed7dc16700053`, SimpleStablecoin
  `0x9e9247Ba864b7421803A4Bf27A11F71B309e034f`, Vault
  `0x4FA94D7e615C4FD84B548Ca8a72b6f30a66B4ceC`. See submission/DEPLOYMENT.md.
- Earlier Forge deployment attempts ran out of gas. The successful run used
  `cast send --create` with explicit gas limits; see submission/DEPLOYMENT.md.
- Etherscan source verification **is done** (2026-10-13): all three contracts have verified
  source. Sourcify lists all three as exact matches.
- The Ex3 screenshot (submission/ex3.png) is a real capture of the live run described in
  submission/ex3-transcript.txt.
