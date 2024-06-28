// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/arks/AaveV3Ark.sol";
import "../src/errors/ArkAccessControlErrors.sol";
import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "./mocks/MockAaveV3Pool.sol";

contract AaveV3ArkTest is Test {
    AaveV3Ark public ark;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    IPoolV3 public aaveV3Pool;
    ERC20Mock public mockToken;

    event Boarded(address indexed commander, address token, uint256 amount);

    function setUp() public {
        mockToken = new ERC20Mock();
        aaveV3Pool = IPoolV3(address(new MockAavePool()));

        ArkParams memory params = ArkParams({governor: governor, raft: raft, token: address(mockToken)});
        ark = new AaveV3Ark(address(aaveV3Pool), params);
    }

    function testBoardArk() public {
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
        vm.expectEmit(true, true, false, true);
        emit Boarded(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount);
    }
}