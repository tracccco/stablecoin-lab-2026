# STUDENT-QUESTIONS.md — Discussion questions (submit with your repo)

Answer directly under each question. 150–300 words each — **reasoning over length**.

---

## A. Permission design

**A1.** The vault holds `MINTER_ROLE`, so it can `burn` any user's balance. Explain why that is a risk, then write out how you would change `Vault` and `SimpleStablecoin` to remove it.

> Your answer:

`MINTER_ROLE` authorizes both creation of sUSD and `burn(from, amount)`. A holder of that role can therefore destroy another holder's tokens without an allowance. Ex4 demonstrates this by impersonating the vault and burning Alice's balance. This establishes the token's authorization boundary; it does not establish that an external attacker can impersonate the deployed vault. The current, non-upgradeable `Vault.redeem` always passes `msg.sender` as the burn target, so an ordinary caller cannot select a victim through that function.

The risk is nevertheless significant: an additional malicious minter, a faulty privileged contract, or an administrator granting the role to an attacker can confiscate balances. The assets at risk are holders' redemption claims. Role checks protect against unprivileged callers but do not limit what privileged callers can do.

I would replace `burn(address,uint256)` with a self-scoped `burn(uint256)` that burns only `msg.sender`'s balance. `Vault.redeem` would first pull the user's approved sUSD through `safeTransferFrom`, burn the vault's received balance, and return collateral atomically. A separate allowance-consuming `burnFrom` is another option. Permit support could reduce approval friction, but is not currently implemented. These changes require revising redemption, liquidation, and pause policy together. They remove arbitrary victim selection, while unbacked minting remains a separate risk requiring tighter mint authority.

<br><br><br>

**A2.** In this contract `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` all go to the same address. How would you split them in production, and who holds each?

> Your answer:

The constructor grants the administrator `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE`; the deployment script then grants mint authority to the vault without revoking the administrator's authority. Consequently, one compromised administrator can mint unbacked tokens, freeze all balance changes, and grant privileges to other addresses. Splitting keys helps only if these existing permissions and the ability to restore them are addressed.

For a production design, I would assign default administration to a governance multisig operating through a timelock. Role changes should be announced and delayed, with independent signers and documented recovery procedures. The default administrator also administers its own role in this implementation, so transferring that role requires careful setup and removal of obsolete authority.

Mint authority should belong only to reviewed collateral-accounting contracts. The deployer's initial mint privilege should be revoked after wiring and testing the vault. Issuance limits and independent backing monitoring can reduce losses from a faulty minter, although they cannot establish solvency by themselves.

Pause authority should belong to a separate emergency multisig that can react quickly. Unpausing and prolonged freezes need explicit governance rules because both operations currently use the same role. Bounded emergency powers reduce indefinite denial of redemption. These are proposed controls, not features of the submitted lab. Even with separate keys, governance can eventually appoint a malicious minter; users still trust governance and its operational security.

<br><br><br>

---

## B. Pausing and redemption

**B1.** `_update` is the single entry point for every balance change, so `pause()` freezes transfers, minting and redemption together. If you wanted "pause transfers but **allow redemption**", how would you change it? Give the approach — full code not required.

> Your answer:

All stablecoin balance changes currently pass through `_update` with `whenNotPaused`. A redemption calls `stable.burn(msg.sender, amount)`, and burning also invokes `_update`, so the same pause blocks transfers, issuance, and exits. Ex4 checks the resulting `EnforcedPause` revert. Collateral remains in the vault because the whole transaction reverts before its transfer completes.

For the existing direct-burn redemption design, I would remove the unconditional modifier and check the operation's endpoints. A mint has a zero sender, a burn has a zero recipient, and an ordinary transfer has two nonzero endpoints. Requiring an unpaused state whenever the recipient is nonzero would block minting and transfers while allowing burns. The collateral token needs to remain transferable, and the vault must retain sufficient collateral and burn authority.

This proposal must be reconciled with A1. If redemption first transfers sUSD into the vault, blocking all transfers would block that preliminary step. An allowance-consuming burn of the redeeming user's tokens avoids it; alternatively a tightly scoped redemption operation could consume an allowance and perform the necessary balance change. A general exemption for transfers to privileged addresses would need careful review to prevent bypasses.

Separate issuance, transfer, and redemption controls make the policy explicit. Redemption might still need an emergency stop for an active collateral-drain bug. Such a stop should have accountable activation and recovery procedures; uninterrupted exits are desirable only when processing them is safe.

<br><br><br>

**B2.** In 2008, when a money-market fund "broke the buck", redemptions were frozen for days. In 2023 USDC depegged to $0.87 after a reserve bank failed, but redemptions were **not** shut. Compare the two responses — what does closing the redemption channel, or leaving it open, do to a stablecoin?

> Your answer:

Closing redemption removes the direct route from a token claim to its backing asset. Holders then depend on secondary-market buyers, who may demand a larger discount because the exit date and recovery value are uncertain. A freeze can also limit forced asset sales and prevent early redeemers from exhausting liquidity at the expense of remaining holders. Its effect depends on whether the underlying problem is temporary illiquidity or actual losses.

The SEC records that the Reserve Primary Fund valued its shares at $0.97 in September 2008 and suspended payment of redemption proceeds. This illustrates an interrupted exit channel, rather than an automatic restoration of value through a contractual dollar promise. [SEC account](https://www.sec.gov/divisions/investment/guidance/reservefundmmffaq.htm).

The USDC comparison needs a qualification: keeping a redemption commitment did not mean uninterrupted dollar settlement throughout the March 2023 weekend. Circle announced that banking operations would resume Monday, March 13, and later reported clearing redemption backlogs. Open access when banking rails operated, together with reserve protection, supported recovery. [Circle operations update](https://www.circle.com/blog/march-15-update-on-usdc-operations).

When reliable dollar redemption is available, eligible arbitrageurs can buy discounted tokens and redeem them, creating demand near par after costs and delays. This mechanism weakens when eligibility, banking hours, or solvency prevent execution. Our lab's global pause removes even the on-chain collateral exit. A better crisis policy distinguishes unsafe transfers or issuance from safe redemption, while retaining a narrowly governed stop for an active exploit.

<br><br><br>

---

## C. Depeg analysis

**C1.** Under what conditions does this coin depeg? Distinguish at least two classes of cause, and say how each one shows up in the invariant `totalCollateral() >= totalSupply()`.

> Your answer:

One class of depeg is insufficient on-chain backing. Ex3 demonstrates that granting an attacker `MINTER_ROLE` permits sUSD issuance without a collateral deposit. Supply rises while `Vault.totalCollateral()` stays constant, violating `totalCollateral() >= totalSupply()`. A hypothetical vault bug that released collateral without reducing liabilities would have the same effect. The privileged issuance path is demonstrated; an arbitrary collateral-drain vulnerability in the current vault is not.

A second class is impaired redeemability or reduced collateral value despite a healthy unit count. Pausing blocks redemption without changing either balance. Holders could discount sUSD because they cannot exit, while the backing invariant still passes. Likewise, if the collateral represented a dollar claim that lost market value, equal token quantities would not imply equal dollar values. An oracle-based value measure and suitable haircuts would address valuation, but introduce additional trust and availability assumptions.

The mock tokens do not have a demonstrated market price, so Ex3 proves an accounting shortfall, not an observed exchange-market quotation. Both tokens use six decimals; their raw quantities can be compared directly. Direct collateral donations can make collateral exceed supply without harm, so inequality is the appropriate backing property.

Ex6 explores only bounded deposits and redemptions by three users. It does not prove safety against role grants, privileged mints, pauses, or collateral devaluation. Ex5 adds price-sensitive collateralization, but its unrestricted mock oracle and price drops can invalidate backing after issuance. Successful tests establish behavior within those scenarios, not a universal dollar peg.

<br><br><br>

**C2.** Suppose an attacker bribes their way to `MINTER_ROLE`, mints 1,000,000 sUSD out of nothing and redeems it all. Describe the flow of funds, and name the step that could have stopped them.

> Your answer:

Assume the vault already holds at least 1,000,000 mUSDC from legitimate deposits and the attacker obtains `MINTER_ROLE`. Calling `mint(attacker, 1_000_000e6)` creates transferable sUSD without moving collateral. At that step supply increases by one million coins and the backing inequality fails. The mock collateral has no real monetary value, but the same accounting pattern would threaten valuable collateral in a production system.

The attacker then calls `Vault.redeem(1_000_000e6)`. The vault checks its collateral balance, burns the attacker's tokens using the vault's role, and transfers the corresponding mUSDC to the attacker. No stablecoin allowance is required. Honest holders' claims remain outstanding against reduced collateral. If the vault has less than that amount, the entire redemption reverts with `InsufficientCollateral`; partial redemptions up to the available balance remain possible while unpaused.

The decisive prevention point is granting or exercising mint authority: restrict issuance to the reviewed deposit contract, revoke deployer mint privileges, and constrain governance changes. Issuance limits can bound exposure. A backing monitor may trigger an emergency response, but separate transactions or a private bundle can complete before an external monitor reacts.

Changing burn to require user consent does not stop this theft: the attacker willingly supplies their own freshly minted tokens for redemption. That change addresses confiscation, not unbacked issuance. Pausing can interrupt redemption but also freezes honest users, so recovery needs a documented response and restoration of backing.

<br><br><br>

---

## D. Toward RWA

**D1.** Right now the collateral is `MockUSDC` and `totalCollateral()` just reads an on-chain balance — simple and reliable. If the collateral were **US Treasuries**, could this invariant still be written that way? What new problems appear?

> Your answer:

The existing invariant compares two on-chain quantities with identical six-decimal scales. A Treasury instrument cannot simply replace mUSDC while preserving that interpretation. A vault might hold tokens representing interests in Treasury assets, but `balanceOf(vault)` would count claims, not establish the value, ownership, availability, or enforceability of the underlying securities.

A proposed system needs an issuer, regulated custody arrangements where applicable, reliable records of beneficial interests, and independent reconciliation between token supply and off-chain holdings. Custodian failure, duplicate pledging, or inaccurate reporting could impair backing without changing any on-chain balance. Token holders also need clearly specified redemption rights and priority if an intermediary becomes insolvent.

Valuation introduces another trust boundary. Treasury prices can change with interest rates, maturity, and liquidity. The solvency measure should use verified quantities multiplied by current prices, less encumbrances, liabilities, and conservative haircuts. An oracle must state its units, update frequency, and failure policy. Ex5 demonstrates decimal conversion and collateral ratios, but its publicly writable mock feed provides no trustworthy real-world valuation.

Liquidity is distinct from solvency. Selling securities and transferring cash involves operational cutoffs and settlement delays, whereas the current vault returns collateral in one transaction. Cash buffers, queues, and explicit redemption terms could bridge that gap, at the cost of capital or slower exits. The invariant therefore survives as a backing objective, but its evidence combines contract accounting with custody verification and legal claims. It cannot be established by one ERC-20 balance read.

<br><br><br>

**D2.** If the collateral were **a building**, how would you put it inside this vault? Which off-chain roles or legal structures would you have to introduce?

> Your answer:

A building would enter the system through a legally enforceable claim rather than a direct token transfer of physical property. One possible structure is a special-purpose vehicle that owns the title and issues defined interests represented by tokens. Documentation must specify whether holders own equity, secured debt, or another claim, and what happens upon default or insolvency. The appropriate structure and transfer restrictions depend on jurisdiction and require legal review.

New actors include the entity manager, property operator, title or security trustee, independent appraiser, auditor, and an administrator reconciling tokens with the legal ownership register. Their permissions and duties form trust boundaries outside Solidity. A fraudulent valuation, undisclosed mortgage, or failure to maintain the property could reduce recoverable value while token balances remain unchanged.

The backing calculation should reflect conservative appraised value minus senior liens, expenses, and other claims. Appraisals are intermittent and realizable sale proceeds may differ substantially, so a fresh-looking oracle timestamp alone is insufficient. Haircuts and issuance limits need to reflect illiquidity and valuation uncertainty rather than copying Ex5's 150% threshold.

Redemption would require cash reserves or a queue linked to asset sales. Liquidation could transfer a tokenized claim on-chain, but taking possession or selling the building depends on contractual and legal enforcement. Ex5's immediate collateral seizure therefore cannot promise immediate cash recovery. Investors need reporting, independent oversight, clear priority rules, and a workable enforcement process. The solvency objective remains meaningful, while its weakest assumptions concern off-chain ownership, valuation, and execution.

<br><br><br>

---

## E. Tests (Tier 1 required — this is Ex4)

Turn the red tests green in `test/exercises/01_LoopTasks.t.sol` to cover the scenarios below, and write your test function names here:

| Scenario | Your test function name |
|---|---|
| Minting by a non-minter reverts | `test_Ex4_Mint_RevertsForNonMinter` |
| Transfers revert while paused | `test_Ex4_Pause_BlocksTransfers` |
| **Redemption** reverts while paused | `test_Ex4_Pause_BlocksRedeem` |
| An attacker cannot burn someone else's balance | `test_Ex4_AttackerCannotBurnOthersBalance` |
| ...but the vault holding `MINTER_ROLE` can | `test_Ex4_VaultHoldsTheKey_CanBurnAnyonesBalance` |

That last pair is meant to be read together: the guard is written correctly, but the key was handed to the vault. Keep it in mind when you answer A1.

Now write one more scenario you consider **most likely to be attacked**, and say why you picked it:

> Your answer:

The most attractive scenario is an administrator granting `MINTER_ROLE` to an attacker,
followed by unbacked issuance and redemption against honest deposits. This creates a
financial incentive and uses supported functions; Ex3 demonstrates the role grant and
mint locally. Theft additionally requires collateral liquidity and an unpaused token.
The risk is a reasoned prioritization, not an empirical prediction of attack frequency.
Restrict minters to reviewed vaults, revoke deployer mint authority after setup, delay
role changes through governance, and monitor backing with a documented emergency response.
Self-scoped burning protects victims from confiscation but does not prevent this attack.
