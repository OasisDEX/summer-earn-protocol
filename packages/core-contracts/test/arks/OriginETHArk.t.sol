// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/OriginETHArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IOriginETH} from "../../src/interfaces/origin/IOriginETH.sol";
import {IOriginETHVault} from "../../src/interfaces/origin/IOriginETHVault.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
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
    IOriginETHVault public originBaseVault;
    IERC20 public weth;
    ArkParams public params;
    address public bufferArk;

    address public constant ORIGINETH_ADDRESS =
        0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3; // IOriginETH address
    address public constant ORIGIN_ETH_VAULT_ADDRESS =
        0x39254033945AA2E4809Cc2977E7087BEE48bd7Ab; // IOriginETHVault address
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH address
    address public constant OETH_WETH_ARM =
        0x6bac785889A4127dB0e0CeFEE88E0a9F1Aaf3cC7; // OETH WETH ARM address

    uint256 forkBlock = 22420334; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(WETH_ADDRESS, "Test Fleet");
        bufferArk = _bufferArk;
        commander = _commander;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IERC20(WETH_ADDRESS);
        originETH = IOriginETH(ORIGINETH_ADDRESS);
        originBaseVault = IOriginETHVault(ORIGIN_ETH_VAULT_ADDRESS);

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

        ark = new OriginETHArk(ORIGINETH_ADDRESS, OETH_WETH_ARM, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCuratorRole(
            address(address(commander)),
            address(curator)
        );
        IFleetCommanderConfigProvider(commander).addArk(address(ark));
        vm.stopPrank();

        vm.startPrank(curator);
        ark.whitelistRouter(ODOS_ROUTER_MAINNET, true);
        vm.stopPrank();

        vm.makePersistent(ORIGINETH_ADDRESS);
        vm.makePersistent(ORIGIN_ETH_VAULT_ADDRESS);
        vm.makePersistent(WETH_ADDRESS);
        vm.makePersistent(OETH_WETH_ARM);
        vm.makePersistent(commander);
        vm.makePersistent(curator);
        vm.makePersistent(governor);
        vm.makePersistent(address(ark));
        vm.makePersistent(0x8309B55488500b7b062c849873717Bff8243061f);
        vm.makePersistent(0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
    }

    function test_Constructor() public {
        // Invalid OriginETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidOriginETHAddress()"));
        ark = new OriginETHArk(address(0), OETH_WETH_ARM, params);

        // Valid constructor
        ark = new OriginETHArk(ORIGINETH_ADDRESS, OETH_WETH_ARM, params);

        assertEq(
            address(ark.originETH()),
            ORIGINETH_ADDRESS,
            "OriginETH address should match"
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

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens - use empty bytes for default minShares (0)
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalSupplyBefore = originETH.totalSupply();
        uint256 totalArkAssetsBefore = ark.totalAssets();

        vm.prank(ORIGIN_ETH_VAULT_ADDRESS);
        originETH.changeSupply(totalSupplyBefore + 1 ether);
        uint256 totalArkAssetsAfter = ark.totalAssets();
        assertLt(
            totalArkAssetsBefore,
            totalArkAssetsAfter,
            "Total assets should accrue interest"
        );
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

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        // Board the tokens with minShares parameter
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Disembark_OriginETH() public {
        test_Board();
        uint256 amount = 1 ether; // 1 WETH

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }

    function test_WithdrawUsingSwap_OriginETH() public {
        test_Board();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559,
                swapCalldata: hex"83bd37f90001856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc30001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080de0b6b3a7640000080de05b2bee779880004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE990001cc7d5785AD5755B6164e21495E07aDb0Ff11C2A80001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef03010203006701010001020001ff00000000000000000000000000000000000000cc7d5785ad5755b6164e21495e07adb0ff11c2a8856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3000000000000000000000000000000000000000000000000"
            });
        bytes memory data = abi.encode(swapData);

        vm.startPrank(keeper);
        ark.withdrawUsingSwap(1 ether, data);
    }

    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(0x123), // Non-whitelisted router
                swapCalldata: hex"83bd37f90001856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc30001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080de0b6b3a7640000080de05b2bee779880004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE990001cc7d5785AD5755B6164e21495E07aDb0Ff11C2A80001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef03010203006701010001020001ff00000000000000000000000000000000000000cc7d5785ad5755b6164e21495e07adb0ff11c2a8856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3000000000000000000000000000000000000000000000000"
            });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(1 ether, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
        assertGt(
            IERC20(ORIGINETH_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be OETH in the ark"
        );
        vm.startPrank(commander);
        ark.requestWithdrawal(type(uint256).max);
        vm.stopPrank();

        assertEq(
            ark.assetsInWithdrawalQueue(),
            amount,
            "Assets in withdrawal queue should match the total balance when using max uint"
        );
        assertEq(
            IERC20(ORIGINETH_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be no OETH in the ark"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 WETH

        // Fund the ark directly with WETH for testing totalAssets
        deal(address(weth), address(ark), amount);
        deal(address(weth), address(commander), amount);

        // board the tokens
        vm.startPrank(commander);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();

        assertEq(
            totalAssets,
            2 * amount,
            "Total assets should match the WETH balance + OriginETH balance"
        );
    }

    function test_RequestWithdrawal() public {
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        assertEq(
            ark.assetsInWithdrawalQueue(),
            amount,
            "Assets in withdrawal queue should match the withdrawal amount"
        );
    }

    function test_ClaimWithdrawal_ClaimDelayNotMet() public {
        // Set withdrawal request ID manually (would normally be set by requestWithdrawal)
        uint256 requestId = 421;
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(
            ark.isWithdrawalClaimRequired(),
            false,
            "Withdrawal claim should not be required"
        );
        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();
        assertEq(
            ark.isWithdrawalClaimRequired(),
            true,
            "Withdrawal claim should be required"
        );

        vm.expectRevert("Claim delay not met");
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            requestId,
            "Withdrawal request ID should be unchanged"
        );
    }

    function test_ClaimWithdrawal_WithdrawalRequestClaimed() public {
        // Set withdrawal request ID manually (would normally be set by requestWithdrawal)
        uint256 requestId = 421;
        uint256 amount = 1 ether; // 1 WETH

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(weth), address(commander), amount);
        weth.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalArkAssetsBeforeRequest = ark.totalAssets();
        assertEq(
            totalArkAssetsBeforeRequest,
            amount,
            "Before request, total assets should be equal to the withdrawal amount"
        );

        vm.startPrank(commander);
        ark.requestWithdrawal(amount);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 minutes);

        uint256 totalArkAssetsBeforeClaim = ark.totalAssets();
        assertEq(
            totalArkAssetsBeforeClaim,
            amount,
            "Before claim, total assets should be equal to the withdrawal amount"
        );

        deal(address(weth), address(originBaseVault), 1000 * amount);
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        uint256 totalArkAssetsAfter = ark.totalAssets();
        assertEq(
            totalArkAssetsAfter,
            amount,
            "After claim, total assets should be equal to the withdrawal amount"
        );
        assertEq(
            IERC20(ORIGINETH_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be no OETH in the ark"
        );
        assertEq(
            IERC20(WETH_ADDRESS).balanceOf(address(ark)),
            amount,
            "There should be WETH in the ark"
        );

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be reset to 0"
        );

        uint256 bufferArkWethBalanceBefore = IERC20(WETH_ADDRESS).balanceOf(
            bufferArk
        );
        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), WETH_ADDRESS, amount);

        vm.prank(keeper);
        ark.sweep();

        vm.assertEq(IERC20(WETH_ADDRESS).balanceOf(address(ark)), 0 ether);
        vm.assertEq(
            IERC20(WETH_ADDRESS).balanceOf(bufferArk),
            bufferArkWethBalanceBefore + amount
        );
    }

    function test_ClaimWithdrawal_NoRequestId() public {
        // Make sure withdrawalRequestId is 0
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be 0"
        );

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        // Should revert with NoWithdrawalRequest
        vm.startPrank(commander);
        vm.expectRevert(abi.encodeWithSignature("NoWithdrawalToClaim()"));
        ark.claimWithdrawal();
        vm.stopPrank();
    }

    function test_WithdrawableAssets() public {
        uint256 arkBalance = 1 ether; // 1 WETH in Ark
        uint256 originBalance = 2 ether; // 2 OETH in Ark
        uint256 armBalance = 1.5 ether; // 1.5 WETH in ARM

        // Fund the Ark with WETH
        deal(address(weth), address(ark), arkBalance);
        assertEq(
            weth.balanceOf(address(ark)),
            arkBalance,
            "WETH balance should match"
        );

        // Fund the Ark with OETH
        deal(address(weth), address(commander), originBalance);
        vm.startPrank(commander);
        weth.forceApprove(address(originBaseVault), originBalance);
        originBaseVault.mint(address(weth), originBalance, originBalance);
        originETH.transfer(address(ark), originBalance);
        vm.stopPrank();
        assertEq(
            originETH.balanceOf(address(ark)),
            originBalance,
            "OriginETH balance should match"
        );

        // Fund the ARM with WETH
        deal(address(weth), OETH_WETH_ARM, armBalance);
        assertEq(
            weth.balanceOf(OETH_WETH_ARM),
            armBalance,
            "WETH balance should match"
        );

        // Calculate expected withdrawable assets
        // Ark's WETH balance + minimum of (Ark's OETH balance, ARM's WETH balance)
        uint256 expectedWithdrawable = arkBalance +
            (originBalance > armBalance ? armBalance : originBalance);

        // Call withdrawableTotalAssets() - We'll need to expose it for testing
        vm.prank(commander);
        uint256 actualWithdrawable = ark.withdrawableTotalAssets();

        vm.startPrank(commander);
        ark.disembark(expectedWithdrawable, bytes(""));
        vm.stopPrank();

        assertEq(weth.balanceOf(address(ark)), 0, "WETH balance should be 0");
        assertEq(
            originETH.balanceOf(address(ark)),
            0.5 ether,
            "OriginETH balance should be 0.5 ether."
        );
        assertEq(weth.balanceOf(OETH_WETH_ARM), 0, "WETH balance should be 0");

        assertEq(
            actualWithdrawable,
            expectedWithdrawable,
            "Withdrawable assets should match expected value"
        );
    }
}
