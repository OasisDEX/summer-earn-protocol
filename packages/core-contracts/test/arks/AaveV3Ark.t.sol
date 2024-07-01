// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/arks/AaveV3Ark.sol";
import "../src/errors/ArkAccessControlErrors.sol";
import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "../src/contracts/ArkEvents.sol";

contract AaveV3ArkTest is Test, ArkEvents {
    AaveV3Ark public ark;
    AaveV3Ark public nextArk;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address constant public aaveV3PoolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    IPoolV3 public aaveV3Pool;
    ERC20Mock public mockToken;

    function setUp() public {
        mockToken = new ERC20Mock();
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

        ArkParams memory params = ArkParams({governor: governor, raft: raft, token: address(mockToken)});
        ark = new AaveV3Ark(address(aaveV3Pool), params);
        nextArk = new AaveV3Ark(address(aaveV3Pool), params);
    }

    function testBoard() public {
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10**18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);

        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(aaveV3Pool.supply.selector, address(mockToken), amount, address(this), 0),
            abi.encode()
        );

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(aaveV3Pool.supply.selector, address(mockToken), amount, address(ark), 0)
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount);
    }

    function testDisembark() public {
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10**18;
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(aaveV3Pool.withdraw.selector, address(mockToken), amount, commander),
            abi.encode(amount)
        );

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(aaveV3Pool.withdraw.selector, address(mockToken), amount, commander)
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.disembark(amount);
    }
}