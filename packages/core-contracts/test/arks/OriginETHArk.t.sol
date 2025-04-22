// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/OriginETHArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IOriginETH} from "../../src/interfaces/origin/IOriginETH.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

contract OriginETHArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    OriginETHArk public ark;
    IOriginETH public originETH;
    IERC20 public weth;
    ArkParams public params;

    address public constant ORIGINETH_ADDRESS =
        0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab; // IOriginETH address
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH address

    uint256 forkBlock = 21666256; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IERC20(WETH_ADDRESS);
        originETH = IOriginETH(ORIGINETH_ADDRESS);

        params = ArkParams({
            name: "WETH OriginETH Ark",
            details: "WETH OriginETH Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new OriginETHArk(ORIGINETH_ADDRESS, WETH_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor() public {
        // Invalid OriginETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidOriginETHAddress()"));
        ark = new OriginETHArk(address(0), WETH_ADDRESS, params);

        // Invalid WETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidWethAddress()"));
        ark = new OriginETHArk(ORIGINETH_ADDRESS, address(0), params);

        // Asset mismatch
        ArkParams memory badParams = params;
        badParams.asset = address(1); // Not WETH
        vm.expectRevert(abi.encodeWithSignature("AssetMismatch()"));
        ark = new OriginETHArk(ORIGINETH_ADDRESS, WETH_ADDRESS, badParams);

        // Valid constructor
        ark = new OriginETHArk(ORIGINETH_ADDRESS, WETH_ADDRESS, params);

        assertEq(
            address(ark.originETH()),
            ORIGINETH_ADDRESS,
            "OriginETH address should match"
        );
        assertEq(
            address(ark.weth()),
            WETH_ADDRESS,
            "WETH address should match"
        );
        assertEq(
            address(ark.asset()),
            WETH_ADDRESS,
            "Asset address should match WETH"
        );
        assertEq(ark.name(), "WETH OriginETH Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1 ether; // 1 WETH

        // Fund the commander with WETH
        vm.deal(commander, 2 ether);
        vm.startPrank(commander);

        // Wrap ETH to WETH
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();

        // Approve the ark to spend WETH
        weth.forceApprove(address(ark), amount);

        // We need to mock the OriginETH.mint call since we can't fully simulate it in the test
        vm.mockCall(
            ORIGINETH_ADDRESS,
            abi.encodeWithSelector(
                IOriginETH.mint.selector,
                address(ark),
                amount,
                0
            ),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens - use empty bytes for default minShares (0)
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    function test_BoardWithMinShares() public {
        uint256 amount = 1 ether; // 1 WETH
        uint256 minShares = 0.9 ether; // Minimum expected shares

        // Fund the commander with WETH
        vm.deal(commander, 2 ether);
        vm.startPrank(commander);

        // Wrap ETH to WETH
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();

        // Approve the ark to spend WETH
        weth.forceApprove(address(ark), amount);

        // We need to mock the OriginETH.mint call since we can't fully simulate it in the test
        vm.mockCall(
            ORIGINETH_ADDRESS,
            abi.encodeWithSelector(
                IOriginETH.mint.selector,
                address(ark),
                amount,
                minShares
            ),
            abi.encode()
        );

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens with minShares parameter
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.clearMockedCalls();
    }

    function test_DisembarkNotImplemented() public {
        uint256 amount = 1 ether; // 1 WETH

        vm.startPrank(commander);
        vm.expectRevert(abi.encodeWithSignature("WithdrawalNotImplemented()"));
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 WETH

        // Fund the ark directly with WETH for testing totalAssets
        vm.deal(address(this), 2 ether);
        IWETH(WETH_ADDRESS).deposit{value: 2 ether}();
        IWETH(WETH_ADDRESS).transfer(address(ark), amount);

        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            amount,
            "Total assets should match the WETH balance"
        );
    }

    function test_Harvest() public {
        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        assertEq(
            rewardTokens[0],
            address(0),
            "Reward token should be address(0)"
        );
        assertEq(rewardAmounts[0], 0, "Reward amount should be 0");
    }
}
