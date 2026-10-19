// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {MockUSDC} from "../src/MockUSDC.sol";
import {SimpleStablecoin} from "../src/SimpleStablecoin.sol";
import {Vault} from "../src/Vault.sol";

/// @notice Deploy the whole loop with one command:
///         MockUSDC (collateral) + SimpleStablecoin (stablecoin) + Vault
///         Finally grant MINTER_ROLE to the vault, or it cannot mint.
contract Deploy is Script {
    function run() external {
        address admin;
        if (vm.envExists("ANVIL_UNLOCKED_SENDER")) {
            admin = vm.envAddress("ANVIL_UNLOCKED_SENDER");
            vm.startBroadcast(admin);
        } else {
            uint256 pk = vm.envUint("PRIVATE_KEY");
            admin = vm.addr(pk);
            vm.startBroadcast(pk);
        }

        MockUSDC usdc = new MockUSDC();
        SimpleStablecoin stable = new SimpleStablecoin(admin);
        Vault vault = new Vault(usdc, stable);

        stable.grantRole(stable.MINTER_ROLE(), address(vault));

        vm.stopBroadcast();

        console.log("admin            :", admin);
        console.log("MockUSDC         :", address(usdc));
        console.log("SimpleStablecoin :", address(stable));
        console.log("Vault            :", address(vault));
    }
}
