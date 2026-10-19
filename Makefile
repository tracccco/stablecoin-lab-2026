SHELL := /bin/bash

# Anvil's unlocked local accounts; no private keys are stored in this project.
ANVIL_ADMIN    := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_ATTACKER := 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
RPC        := http://127.0.0.1:8545

.PHONY: help setup doctor install-foundry test exercise challenge fmt anvil deploy-anvil snapshot restore mint balance clean deploy-sepolia package-submission

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: ## Reinstall lib/ dependencies (rarely needed — lib/ ships with the repo; if lib/ is empty prefer git checkout -- lib)
	@git rev-parse --git-dir >/dev/null 2>&1 || git init -q
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
	@echo "done — dependencies ready"

doctor: ## Pre-class self-check: can this machine run the lab? 30 seconds to an answer
	bash scripts/doctor.sh

install-foundry: ## Install Foundry (no foundryup, switches to a mainland mirror automatically)
	bash scripts/install-foundry-cn.sh

test: ## Run the core lab tests (Ex0 checkpoint, should be all green)
	forge test --no-match-path 'test/{challenges,exercises}/*' -vv

exercise: ## Run the student exercises Ex2/Ex4/Ex5/Ex6 (red until you finish them)
	forge test --match-path 'test/exercises/*.t.sol' -vv

challenge: ## Run the challenge (fails until the student solves it)
	forge test --match-path 'test/challenges/Unstoppable.t.sol' -vv

fmt: ## Format the contracts
	forge fmt

anvil: ## Start a local chain (in a second terminal)
	anvil

deploy-anvil: ## Deploy to the local chain
	ANVIL_UNLOCKED_SENDER=$(ANVIL_ADMIN) forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RPC) --broadcast --unlocked --sender $(ANVIL_ADMIN)

snapshot: ## Start a chain and save its state on exit as a snapshot (Ctrl-C saves)
	@echo "run the whole demo once, then Ctrl-C — state goes to demo-state.json"
	anvil --dump-state demo-state.json --port 8545

restore: ## Restore chain state from the snapshot, for when the demo goes sideways
	anvil --load-state demo-state.json --port 8545

## The commands below need VAULT=... SUSD=... USDC=... exported first
mint: ## make mint AMOUNT=1000000000  mint stablecoin to yourself via the vault
	cast send $(VAULT) "deposit(uint256)" $(AMOUNT) --rpc-url $(RPC) --unlocked --from $(ANVIL_ADMIN)

balance: ## make balance TO=0xf39F...  check a stablecoin balance
	cast call $(SUSD) "balanceOf(address)(uint256)" $(TO) --rpc-url $(RPC)

deploy-sepolia: ## Deploy to Sepolia and print the three Etherscan links (reads .env, never prints secrets)
	bash scripts/deploy-sepolia.sh

package-submission: ## Build the Moodle submission ZIP next to the project directory
	bash scripts/package-submission.sh

clean: ## Remove build artifacts
	forge clean
