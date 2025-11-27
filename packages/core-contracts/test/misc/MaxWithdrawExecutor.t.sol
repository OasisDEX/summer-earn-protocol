// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MaxWithdrawExecutor} from "../../src/contracts/misc/MaxWithdrawExecutor.sol";
interface IERC4626Minimal {
    function maxWithdraw(address owner) external view returns (uint256);
}

contract MaxWithdrawExecutorTest is Test {
    string arbitrum;
    uint256 public day = 60 * 60 * 24;
    uint256 public hour = 60 * 60;

    function setUp() public {}
    function test_MaxWithdrawExecutor_Fork_Arbitrum() public {
        arbitrum = vm.rpcUrl("arbitrum");
        uint256 forkId = vm.createSelectFork(arbitrum, 396490669);

        // Hardcoded addresses from script/contract
        address siloAddress = 0x2433D6AC11193b4695D9ca73530de93c538aD18a;
        address arkAddress = 0x54749c15751137Be18768288D3945C4934fCb800;
        address timelock = 0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796;
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        // Deploy the executor (deployer becomes contract owner for onlyOwner)
        MaxWithdrawExecutor exec = new MaxWithdrawExecutor(address(this));

        // Transfer shares to timelock ( in an old block when liquidity was available)
        vm.startPrank(arkAddress);
        IERC20(siloAddress).transfer(
            timelock,
            IERC20(siloAddress).balanceOf(arkAddress)
        );
        vm.stopPrank();
        vm.startPrank(timelock);
        IERC20(siloAddress).approve(address(exec), type(uint256).max);
        vm.stopPrank();
        uint256 ownerBalanceBefore = IERC20(usdc).balanceOf(timelock);
        // Determine expectation based on current maxWithdraw
        uint256 maxW = IERC4626Minimal(siloAddress).maxWithdraw(timelock);

        if (maxW > 0) {
            exec.execute();
        } else {
            vm.expectRevert(MaxWithdrawExecutor.NothingToWithdraw.selector);
            exec.execute();
        }

        uint256 ownerBalanceAfter = IERC20(usdc).balanceOf(timelock);
        console.log("ownerBalanceBefore: %s USDC", ownerBalanceBefore / 1e6);
        console.log("ownerBalanceAfter: %s USDC", ownerBalanceAfter / 1e6);
        console.log(
            "delta: %s USDC",
            (ownerBalanceAfter - ownerBalanceBefore) / 1e6
        );
        console.log("maxW: %s USDC", maxW / 1e6);
    }
}
