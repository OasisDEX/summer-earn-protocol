// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/FluidLiteArk.sol";
import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IEthVaultWrapperV2} from "../../src/interfaces/fluid/IEthVaultWrapperV2.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../../src/interfaces/misc/IWETH.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract FluidLiteArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    FluidLiteArk public ark;
    IERC4626 public vault;
    IWETH public weth;
    ArkParams public params;
    IEthVaultWrapperV2 public wrapper;
    IWithdrawalQueue public withdrawalQueue;
    address bufferArk;

    // Router and vault addresses provided in the requirement
    address public constant ROUTER_ADDRESS =
        0x64338FD8e7b1918B4a806A175e26eD152B3d0b7b;
    address public constant VAULT_ADDRESS =
        0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78;

    // Using Ethereum Mainnet WETH
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant STETH_ADDRESS =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WITHDRAWAL_QUEUE_ADDRESS =
        0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address public constant LIDO_FINALIZER_ADDRESS =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    uint256 forkBlock = 22420969; // Setting a fairly recent block number on Ethereum mainnet
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        withdrawalQueue = IWithdrawalQueue(WITHDRAWAL_QUEUE_ADDRESS);
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(WETH_ADDRESS, "Test Fleet");
        commander = _commander;
        bufferArk = _bufferArk;

        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IWETH(WETH_ADDRESS);
        vault = IERC4626(VAULT_ADDRESS);
        wrapper = IEthVaultWrapperV2(ROUTER_ADDRESS);

        params = ArkParams({
            name: "FluidLite ETH Ark",
            details: "FluidLite ETH Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: WETH_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false, // We require keeper data for signature authorization
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

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

        vm.label(WETH_ADDRESS, "WETH");
        vm.label(STETH_ADDRESS, "STETH");
        vm.label(ROUTER_ADDRESS, "ROUTER");
        vm.label(VAULT_ADDRESS, "VAULT");
        vm.label(address(ark), "ARK");
        vm.label(0x17144556fd3424EDC8Fc8A4C940B2D04936d17eb, "STETH_IMPL");
    }

    function test_Constructor() public {
        // Test with invalid router address
        vm.expectRevert(abi.encodeWithSignature("InvalidWrapperAddress()"));
        new FluidLiteArk(
            address(0),
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        // Test with invalid vault address
        vm.expectRevert(abi.encodeWithSignature("InvalidVaultAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            address(0),
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        // Test with invalid WETH address
        vm.expectRevert(abi.encodeWithSignature("InvalidWETHAddress()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            address(0),
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        // Test with non-WETH asset
        ArkParams memory badParams = params;
        badParams.asset = address(0x123); // Some random address that isn't WETH
        vm.expectRevert(abi.encodeWithSignature("AssetMustBeWETH()"));
        new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            badParams
        );

        // Valid constructor
        FluidLiteArk validArk = new FluidLiteArk(
            ROUTER_ADDRESS,
            VAULT_ADDRESS,
            WETH_ADDRESS,
            STETH_ADDRESS,
            WITHDRAWAL_QUEUE_ADDRESS,
            params
        );

        assertEq(
            address(validArk.wrapper()),
            ROUTER_ADDRESS,
            "Wrapper address should match"
        );
        assertEq(
            address(validArk.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(validArk.weth()),
            WETH_ADDRESS,
            "WETH address should match"
        );
        assertEq(validArk.name(), "FluidLite ETH Ark", "Ark name should match");
    }

    function test_Board_FluidLite() public {
        uint256 amount = 1 ether; // 1 ETH

        // Fund commander with WETH
        deal(WETH_ADDRESS, commander, amount);

        vm.startPrank(commander);
        IERC20(WETH_ADDRESS).approve(address(ark), amount);

        vm.expectEmit(true, true, false, true);
        emit Boarded(commander, WETH_ADDRESS, amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Verify totalAssets returns the expected amount
        uint256 totalAssets = ark.totalAssets();
        assertApproxEqAbs(
            totalAssets,
            amount,
            1,
            "Total assets should match deposited amount"
        );
    }

    function test_Disembark() public {
        console.log("not implemented");
    }

    function test_WithdrawUsingSwap() public {
        test_Board_FluidLite();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559,
                swapCalldata: hex"83bd37f90001ae7ab96520de3a18e5e111b5eaab095312d7fe840001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080DDEEFF45500BFFF080ddabc115667a180004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE9900000001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef05010206004c0101026800010102030405ff000000000000000000000000000000c4ce391d82d164c166df9c8336ddf84206b2f8127f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2775f661b0bd1739349b9a2a3ef60be277c5d2d290fe906e030a44ef24ca8c7dc7b7c53a6c4f00ce900000000000000000000000000000000000000000000000000000000"
            });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        ark.withdrawUsingSwap(1 ether - 1, data);
    }

    function test_WithdrawUsingSwap_NonWhitelistedRouter() public {
        test_Board_FluidLite();
        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: address(0x123), // Non-whitelisted router
                swapCalldata: hex"83bd37f90001ae7ab96520de3a18e5e111b5eaab095312d7fe840001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2080DDEEFF45500BFFF080ddabc115667a180004189000176edF8C155A1e0D9B2aD11B04d9671CBC25fEE9900000001A4AD4f68d0b91CFD19687c881e50f3A00242828c1f1508ef05010206004c0101026800010102030405ff000000000000000000000000000000c4ce391d82d164c166df9c8336ddf84206b2f8127f39c581f595b53c5cb19bd0b3f8da6c935e2ca0c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2775f661b0bd1739349b9a2a3ef60be277c5d2d290fe906e030a44ef24ca8c7dc7b7c53a6c4f00ce900000000000000000000000000000000000000000000000000000000"
            });
        bytes memory data = abi.encode(swapData);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSignature("RouterNotWhitelisted()"));
        ark.withdrawUsingSwap(1 ether - 1, data);
    }

    function test_RequestWithdrawal_MaxUint() public {
        test_Board_FluidLite();
        uint256 amount = 1 ether; // 1 ETH

        assertGt(
            IERC20(address(vault)).balanceOf(address(ark)),
            0,
            "There should be vault shares in the ark"
        );
        vm.prank(keeper);
        vm.warp(block.timestamp + 100);

        ark.requestWithdrawal(type(uint256).max);
        // apply the 0.05% fee and round down
        assertEq(
            ark.assetsInWithdrawalQueue(),
            (9995 * (amount - 1)) / 10000,
            "Assets in withdrawal queue should match the total balance when using max uint"
        );
        assertEq(
            IERC20(address(vault)).balanceOf(address(ark)),
            0,
            "There should be no vault shares in the ark"
        );
    }

    function test_ClaimWithdrawalLido() public {
        assertEq(
            ark.isWithdrawalClaimRequired(),
            false,
            "Withdrawal claim should not be required"
        );
        test_RequestWithdrawal();
        assertEq(
            ark.isWithdrawalClaimRequired(),
            true,
            "Withdrawal claim should be required"
        );
        vm.prank(keeper);
        uint256 arkRequestId = ark.withdrawalRequestId();
        vm.prank(LIDO_FINALIZER_ADDRESS);
        withdrawalQueue.finalize(arkRequestId, type(uint256).max);

        vm.prank(keeper);
        ark.claimWithdrawal();

        uint256 requestedAmount = 1 ether;
        uint256 requestAmountAfterFluidFee = (9995 * (requestedAmount - 1)) /
            10000;
        vm.assertEq(address(ark).balance, 0);
        vm.assertEq(
            IERC20(WETH_ADDRESS).balanceOf(address(ark)),
            requestAmountAfterFluidFee
        );
        // lefotever
        vm.assertEq(IERC20(STETH_ADDRESS).balanceOf(address(ark)), 1);

        uint256 bufferArkWethBalanceBefore = IERC20(WETH_ADDRESS).balanceOf(
            bufferArk
        );
        vm.expectEmit(true, true, true, true);
        emit Disembarked(
            address(keeper),
            WETH_ADDRESS,
            requestAmountAfterFluidFee
        );

        vm.prank(keeper);
        ark.sweep();

        vm.assertEq(IERC20(WETH_ADDRESS).balanceOf(address(ark)), 0 ether);
        vm.assertEq(
            IERC20(WETH_ADDRESS).balanceOf(bufferArk),
            bufferArkWethBalanceBefore + requestAmountAfterFluidFee
        );
    }

    function test_RequestWithdrawal() public {
        test_Board_FluidLite();

        uint256 amount = 1 ether; // 1 ETH
        vm.prank(keeper);
        vm.warp(block.timestamp + 100);
        ark.requestWithdrawal(amount - 1);
        assertEq(
            ark.assetsInWithdrawalQueue(),
            (9995 * (amount - 1)) / 10000,
            "Assets in withdrawal queue should match the withdrawal amount"
        );
    }

    function test_claimWithdrawal_revert() public {
        test_RequestWithdrawal();
        vm.prank(keeper);
        vm.warp(block.timestamp + 100);
        vm.expectRevert();
        ark.claimWithdrawal();
    }

    function test_TotalAssets() public {
        uint256 amount = 1 ether; // 1 ETH

        // Give the ark some WETH directly
        deal(WETH_ADDRESS, address(ark), 0.5 ether);

        // Mock vault balanceOf to simulate shares held
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(0.5 ether)
        );

        // Mock vault convertToAssets to return the value of shares
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(
                IERC4626.convertToAssets.selector,
                0.5 ether
            ),
            abi.encode(0.5 ether)
        );

        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            amount,
            "Total assets should be sum of direct WETH plus vault assets"
        );
    }

    function test_Harvest() public {
        // Mock vault balanceOf to simulate shares held
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(ark)),
            abi.encode(1 ether)
        );

        // Mock vault convertToAssets to return slightly more than initial value
        vm.mockCall(
            VAULT_ADDRESS,
            abi.encodeWithSelector(IERC4626.convertToAssets.selector, 1 ether),
            abi.encode(1.05 ether) // 5% yield
        );

        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        assertEq(
            rewardTokens.length,
            0,
            "No explicit reward tokens should be returned"
        );
        assertEq(
            rewardAmounts.length,
            0,
            "No explicit reward amounts should be returned"
        );

        uint256 totalAssets = ark.totalAssets();
        assertEq(
            totalAssets,
            1.05 ether,
            "Total assets should include auto-compounded yield"
        );
    }
}
