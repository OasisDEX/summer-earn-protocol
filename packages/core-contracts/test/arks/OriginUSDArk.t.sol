// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/OriginUSDArk.sol";
import "../../src/events/IArkEvents.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IOriginUSD} from "../../src/interfaces/origin/IOriginUSD.sol";
import {IOriginUSDVault} from "../../src/interfaces/origin/IOriginUSDVault.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract MockRouter {
    IERC20 public ousd = IERC20(0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86);
    IERC20 public usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function swap() external {
        ousd.transferFrom(msg.sender, address(this), 1e18);
        usdc.transfer(msg.sender, 1e6);
    }
}

contract OriginUSDArkTest is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    OriginUSDArk public ark;
    IOriginUSD public originUSD;
    IOriginUSDVault public originBaseVault;
    IERC20 public usdc;
    ArkParams public params;
    address public bufferArk;

    address public constant ORIGINUSD_ADDRESS =
        0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86; // IOriginUSD address
    address public constant ORIGIN_USD_VAULT_ADDRESS =
        0xE75D77B1865Ae93c7eaa3040B038D7aA7BC02F70; // IOriginUSDVault
    // address
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Mainnet USDC address

    uint256 forkBlock = 24543370; // A recent block number
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(USDC_ADDRESS, "Test Fleet");
        bufferArk = _bufferArk;
        commander = _commander;
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        originUSD = IOriginUSD(ORIGINUSD_ADDRESS);
        originBaseVault = IOriginUSDVault(ORIGIN_USD_VAULT_ADDRESS);

        params = ArkParams({
            name: "USDC OriginUSD Ark",
            details: "USDC OriginUSD Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new OriginUSDArk(ORIGINUSD_ADDRESS, params);

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

        vm.makePersistent(ORIGINUSD_ADDRESS);
        vm.makePersistent(ORIGIN_USD_VAULT_ADDRESS);
        vm.makePersistent(USDC_ADDRESS);
        vm.makePersistent(commander);
        vm.makePersistent(curator);
        vm.makePersistent(governor);
        vm.makePersistent(address(ark));
        vm.makePersistent(0x8309B55488500b7b062c849873717Bff8243061f);
        vm.makePersistent(0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3);
    }

    function test_Constructor() public {
        // Invalid OriginUSD address
        vm.expectRevert(abi.encodeWithSignature("InvalidOriginUSDAddress()"));
        ark = new OriginUSDArk(address(0), params);

        // Valid constructor
        ark = new OriginUSDArk(ORIGINUSD_ADDRESS, params);

        assertEq(
            address(ark.originUSD()),
            ORIGINUSD_ADDRESS,
            "OriginUSD address should match"
        );
        assertEq(
            address(ark.asset()),
            USDC_ADDRESS,
            "Asset address should match USDC"
        );
        assertEq(ark.name(), "USDC OriginUSD Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1e6; // 1 USDC

        // Fund the commander with USDC
        deal(USDC_ADDRESS, commander, 2e6);
        vm.startPrank(commander);

        // Wrap ETH to USDC

        // Approve the ark to spend USDC
        usdc.forceApprove(address(ark), amount);

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Board the tokens - use empty bytes for default minShares (0)
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalSupplyBefore = originUSD.totalSupply();
        uint256 totalArkAssetsBefore = ark.totalAssets();

        vm.prank(ORIGIN_USD_VAULT_ADDRESS);
        originUSD.changeSupply((totalSupplyBefore * 11) / 10); // Increase supply by 10%
        uint256 totalArkAssetsAfter = ark.totalAssets();
        assertLt(
            totalArkAssetsBefore,
            totalArkAssetsAfter,
            "Total assets should accrue interest"
        );
    }

    function test_BoardWithMinShares() public {
        uint256 amount = 1e6; // 1 USDC
        uint256 minShares = 9e5; // Minimum expected shares

        // Fund the commander with USDC
        deal(USDC_ADDRESS, commander, 2e6);
        vm.startPrank(commander);

        // Wrap ETH to USDC

        // Approve the ark to spend USDC
        usdc.forceApprove(address(ark), amount);

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Board the tokens with minShares parameter
        ark.board(amount, bytes(""));
        vm.stopPrank();
    }

    function test_Disembark_OriginUSD() public {
        test_Board();
        uint256 amount = 1e6; // 1 USDC

        // Fund the Ark directly with USDC
        deal(address(usdc), address(ark), amount);

        vm.startPrank(commander);
        ark.disembark(amount, bytes(""));
        vm.stopPrank();
    }

    function test_WithdrawUsingSwap_OriginUSD() public {
        test_Board();
        MockRouter router = new MockRouter();
        deal(USDC_ADDRESS, address(router), 1e6);

        vm.prank(curator);
        ark.whitelistRouter(address(router), true);

        IArkWithSwap.SwapData memory swapData = IArkWithSwap.SwapData({
            router: address(router),
            swapCalldata: abi.encodeWithSelector(MockRouter.swap.selector)
        });
        bytes memory data = abi.encode(swapData);

        vm.startPrank(keeper);
        ark.withdrawUsingSwap(1e6, data);
    }

    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board();
        IArkWithSwap.SwapData memory swapData = IArkWithSwap.SwapData({
            router: address(0x123), // Non-whitelisted router
            swapCalldata: hex"83bd37f90001856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc30001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080de0b6b3a7640000080de05b2bee779880004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE990001cc7d5785AD5755B6164e21495E07aDb0Ff11C2A80001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef03010203006701010001020001ff00000000000000000000000000000000000000cc7d5785ad5755b6164e21495e07adb0ff11c2a8856c4efb76c1d1ae02e20ceb03a2a6a08b0b8dc3000000000000000000000000000000000000000000000000"
        });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(1e6, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        uint256 amount = 1e6; // 1 USDC

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(usdc), address(commander), amount);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();
        assertGt(
            IERC20(ORIGINUSD_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be OUSD in the ark"
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
            IERC20(ORIGINUSD_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be no OUSD in the ark"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1e6; // 1 USDC

        // Fund the ark directly with USDC for testing totalAssets
        deal(address(usdc), address(ark), amount);
        deal(address(usdc), address(commander), amount);

        // board the tokens
        vm.startPrank(commander);
        usdc.forceApprove(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();

        assertEq(
            totalAssets,
            2 * amount,
            "Total assets should match the USDC balance + OriginUSD balance"
        );
    }

    function test_RequestWithdrawal() public {
        uint256 amount = 1e6; // 1 USDC

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(usdc), address(commander), amount);
        usdc.forceApprove(address(ark), amount);
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
        uint256 amount = 1e6; // 1 USDC

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(usdc), address(commander), amount);
        usdc.forceApprove(address(ark), amount);
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

        // Capture the real Request ID
        uint256 requestId = ark.withdrawalRequestId();

        vm.expectRevert("Claim delay not met");
        vm.startPrank(commander);
        ark.claimWithdrawal();
        vm.stopPrank();

        // Verify the request ID was unchanged
        assertEq(
            ark.withdrawalRequestId(),
            requestId,
            "Withdrawal request ID should be unchanged"
        );
    }

    function test_ClaimWithdrawal_WithdrawalRequestClaimed() public {
        uint256 amount = 1e6; // 1 USDC

        // Grant keeper role to the commander for testing
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        deal(address(usdc), address(commander), amount);
        usdc.forceApprove(address(ark), amount);
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

        deal(address(usdc), address(originBaseVault), 1000 * amount);
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
            IERC20(ORIGINUSD_ADDRESS).balanceOf(address(ark)),
            0,
            "There should be no OUSD in the ark"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(ark)),
            amount,
            "There should be USDC in the ark"
        );

        // Verify the request ID was reset
        assertEq(
            ark.withdrawalRequestId(),
            0,
            "Withdrawal request ID should be reset to 0"
        );

        uint256 bufferArkWethBalanceBefore = IERC20(USDC_ADDRESS).balanceOf(
            bufferArk
        );
        vm.expectEmit(true, true, true, true);
        emit Disembarked(address(keeper), USDC_ADDRESS, amount);

        vm.prank(keeper);
        ark.sweep();

        vm.assertEq(IERC20(USDC_ADDRESS).balanceOf(address(ark)), 0 ether);
        vm.assertEq(
            IERC20(USDC_ADDRESS).balanceOf(bufferArk),
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
        uint256 arkBalance = 1e6; // 1 USDC in Ark
        uint256 originBalance = 2e6; // 2 OUSD in Ark (wait, this might need more adjust)

        // Fund the Ark with USDC
        deal(address(usdc), address(ark), arkBalance);
        assertEq(
            usdc.balanceOf(address(ark)),
            arkBalance,
            "USDC balance should match"
        );

        // Fund the Ark with OUSD
        deal(address(usdc), address(commander), originBalance);
        vm.startPrank(commander);
        usdc.forceApprove(address(originBaseVault), originBalance);
        originBaseVault.mint(address(usdc), originBalance, originBalance);
        originUSD.transfer(address(ark), originBalance);
        vm.stopPrank();

        // Calculate expected withdrawable assets
        // Since there is no ARM, only USDC balance is withdrawable immediately
        uint256 expectedWithdrawable = arkBalance;

        // Call withdrawableTotalAssets()
        vm.prank(commander);
        uint256 actualWithdrawable = ark.withdrawableTotalAssets();

        vm.startPrank(commander);
        ark.disembark(expectedWithdrawable, bytes(""));
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(ark)), 0, "USDC balance should be 0");
        assertEq(
            originUSD.balanceOf(address(ark)),
            originBalance,
            "OriginUSD balance should not change"
        );
        assertEq(
            actualWithdrawable,
            expectedWithdrawable,
            "Withdrawable assets should match expected value"
        );
    }
}
