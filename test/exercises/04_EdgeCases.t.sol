// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OverCollateralTasksTest} from "./03_OverCollateralTasks.t.sol";
import {OverCollateralizedVault} from "../../src/exercises/OverCollateralizedVault.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @dev Extra checks for precision, liquidation eligibility, and atomic accounting.
contract OverCollateralEdgeCasesTest is OverCollateralTasksTest {
    function test_Value_FullPrecisionIntermediate() public view {
        uint256 amount = type(uint256).max;
        // At $2000 the exact conversion simplifies to division by 500,000,000.
        assertEq(vault.collateralValue(amount), amount / 500_000_000);
    }

    function test_Value_RejectsNonpositivePrice() public {
        feed.setPrice(0);
        vm.expectRevert(OverCollateralizedVault.ZeroAmount.selector);
        vault.collateralValue(1e18);
        feed.setPrice(-1);
        vm.expectRevert(OverCollateralizedVault.ZeroAmount.selector);
        vault.collateralValue(1e18);
    }

    function test_RepayThenWithdrawAll() public {
        _deposit(alice, 1e18);
        vm.startPrank(alice);
        vault.mintStable(1000e6);
        vault.repay(1000e6);
        vault.redeemCollateral(1e18);
        vm.stopPrank();
        assertEq(vault.debtOf(alice), 0);
        assertEq(vault.collateralOf(alice), 0);
        assertEq(stable.totalSupply(), 0);
        assertEq(weth.balanceOf(alice), 10e18);
    }

    function test_Liquidation_Exact120IsHealthy() public {
        _deposit(alice, 1e18);
        vm.prank(alice);
        vault.mintStable(1000e6);
        feed.setPrice(1200e8);
        vm.expectRevert(OverCollateralizedVault.NotLiquidatable.selector);
        vm.prank(bob);
        vault.liquidate(alice);
        assertEq(vault.debtOf(alice), 1000e6);
    }

    function test_Liquidation_PausedBurnRollsBackAccounting() public {
        _deposit(alice, 1e18);
        vm.startPrank(alice);
        vault.mintStable(1000e6);
        stable.transfer(bob, 1000e6);
        vm.stopPrank();
        feed.setPrice(1000e8);
        stable.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(bob);
        vault.liquidate(alice);
        assertEq(vault.debtOf(alice), 1000e6);
        assertEq(vault.collateralOf(alice), 1e18);
        assertEq(stable.balanceOf(bob), 1000e6);
        assertEq(weth.balanceOf(address(vault)), 1e18);
    }
}
