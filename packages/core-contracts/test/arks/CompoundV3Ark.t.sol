// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/CompoundV3Ark.sol";
import "../../src/errors/ArkAccessControlErrors.sol";
import "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract CompoundV3ArkTest is Test {
    CompoundV3Ark public ark;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address constant public cometAddress = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    CometMainInterface public comet;
    ERC20Mock public mockToken;

    event Boarded(address indexed commander, address token, uint256 amount);
    event Moved(address indexed commander, uint256 amount, address indexed newArk);
    event Disembarked(address indexed commander, address token, uint256 amount);

    function setUp() public {
        mockToken = new ERC20Mock();
        comet = CometMainInterface(cometAddress);

        ArkParams memory params = ArkParams({governor: governor, raft: raft, token: address(mockToken)});
        ark = new CompoundV3Ark(address(comet), params);
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
            address(comet),
            abi.encodeWithSelector(comet.supply.selector, address(mockToken), amount),
            abi.encode()
        );

        vm.expectCall(
            address(comet),
            abi.encodeWithSelector(comet.supply.selector, address(mockToken), amount)
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
            address(comet),
            abi.encodeWithSelector(comet.withdraw.selector, address(mockToken), amount),
            abi.encode(amount)
        );

        vm.expectCall(
            address(comet),
            abi.encodeWithSelector(comet.withdraw.selector, address(mockToken), amount)
        );

        // Expect the Disembarked event to be emitted
        vm.expectEmit();
        emit Disembarked(commander, address(mockToken), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.disembark(amount);
    }

    function testMove() public {
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10**18;
        mockToken.mint(commander, amount);
        vm.prank(commander);
        mockToken.approve(address(ark), amount);
        mockToken.mint(address(ark), amount);

        vm.mockCall(
            address(comet),
            abi.encodeWithSelector(comet.withdraw.selector, address(mockToken), amount),
            abi.encode(amount)
        );

        vm.expectCall(
            address(comet),
            abi.encodeWithSelector(comet.withdraw.selector, address(mockToken), amount)
        );

        // Expect the Moved event to be emitted
        vm.expectEmit();
        emit Moved(commander, amount, address(ark));

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.move(amount, address(ark)); // Move it to itself
    }
}
