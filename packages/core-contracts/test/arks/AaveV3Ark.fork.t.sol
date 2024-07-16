// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/AaveV3Ark.sol";
import "../../src/errors/AccessControlErrors.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";

contract AaveV3ArkTestFork is Test, IArkEvents {
    AaveV3Ark public ark;
    AaveV3Ark public nextArk;
    address public governor = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address public constant aaveV3PoolAddress =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public aaveAddressProvider =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public aaveV3DataProvider =
        0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;
    address public rewardsController = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;

    IPoolV3 public aaveV3Pool;
    IERC20 public dai;

    uint256 forkBlock = 20276596;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        aaveV3Pool = IPoolV3(aaveV3PoolAddress);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: address(dai)
        });

        ark = new AaveV3Ark(address(aaveV3Pool), rewardsController, params);
        nextArk = new AaveV3Ark(address(aaveV3Pool), rewardsController, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
        nextArk.grantCommanderRole(commander);
        vm.stopPrank();
    }

    function test_Board_AaveV3_fork() public {
        vm.prank(governor); // Set msg.sender to governor
        ark.grantCommanderRole(commander);

        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(address(dai), commander, amount);

        vm.prank(commander);
        dai.approve(address(ark), amount);

        vm.expectCall(
            address(aaveV3Pool),
            abi.encodeWithSelector(
                aaveV3Pool.supply.selector,
                address(dai),
                amount,
                address(ark),
                0
            )
        );

        // Expect the Transfer event to be emitted - minted aTokens
        vm.expectEmit();
        emit IERC20.Transfer(
            0x0000000000000000000000000000000000000000,
            address(ark),
            amount
        );

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, address(dai), amount);

        // Act
        vm.prank(commander); // Execute the next call as the commander
        ark.board(amount);

        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(assetsAfterAccrual > assetsAfterDeposit);
    }
}
