// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import "../../src/contracts/arks/ERC4626Ark.sol";

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {IFleetCommanderWhitelist} from "../../src/interfaces/IFleetCommanderWhitelist.sol";
import {FleetCommanderParams, FleetCommanderWhitelistParams, FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {MockSummerGovernor} from "../mocks/MockSummerGovernor.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {RoundsVaultOutput} from "../../src/contracts/rounds-vault/RoundsVaultOutput.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

contract RoundsFleetLifecycleTest is Test, TestHelpers, FleetCommanderTestBase {
    ERC4626Ark public usdcGearboxERC4626Ark;
    BufferArk public usdcBufferArk;

    address[] public usdcArks;

    IERC20 public usdcTokenContract;
    IERC4626 public gearboxUsdcVault;

    // Constants
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant GEARBOX_USDC_VAULT_ADDRESS =
        0xda00000035fef4082F78dEF6A8903bee419FbF8E;
    uint256 constant FORK_BLOCK = 20376149;

    FleetCommanderWhitelist public usdcFleetCommander;

    function setUp() public {
        console.log("Setting up RoundsFleetLifecycleTest");

        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        accessManager = new ProtocolAccessManagerV2(governor);

        uint256 initialTipRate = 0;
        setupExternalContracts();
        setupFleetCommanders(initialTipRate);
        setupArks();
        addArksToFleetCommanders();
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);
        gearboxUsdcVault = IERC4626(GEARBOX_USDC_VAULT_ADDRESS);
    }

    function setupArks() internal {
        ArkParams memory usdcArkParams = ArkParams({
            name: "USDC Ark",
            details: "USDC Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // USDC Arks
        usdcGearboxERC4626Ark = new ERC4626Ark(
            GEARBOX_USDC_VAULT_ADDRESS,
            usdcArkParams
        );
    }

    function setupFleetCommanders(uint256 initialTipRate) internal {
        setupBaseContracts();
        vm.startPrank(governor);

        if (address(mockGovernor) == address(0)) {
            mockGovernor = new MockSummerGovernor();
        }

        for (uint256 i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        FleetCommanderWhitelistParams
            memory whitelistParams = FleetCommanderWhitelistParams({
                accessManager: address(accessManager),
                configurationManager: address(configurationManager),
                initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
                initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
                asset: USDC_ADDRESS,
                name: fleetName,
                symbol: "TEST-SUM",
                details: "TestFleet-details",
                initialTipRate: PercentageUtils.fromIntegerPercentage(
                    initialTipRate
                ),
                depositCap: type(uint256).max,
                isOperatorGatewayOpen: false
            });

        FleetCommanderWhitelist f = new FleetCommanderWhitelist(
            whitelistParams
        );
        usdcFleetCommander = FleetCommanderWhitelist(address(f));
        fleetCommander = FleetCommander(address(f));

        bufferArkAddress = f.bufferArk();
        bufferArk = BufferArk(bufferArkAddress);
        usdcBufferArk = bufferArk;

        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(f)
        );
        harborCommand.enlistFleetCommander(address(f));
        vm.stopPrank();
    }

    function addArksToFleetCommanders() internal {
        usdcArks = new address[](1);
        usdcArks[0] = address(usdcGearboxERC4626Ark);

        grantPermissions();

        vm.startPrank(governor);
        for (uint256 i = 0; i < usdcArks.length; i++) {
            usdcFleetCommander.addArk(usdcArks[i]);
        }
        vm.stopPrank();
    }

    function grantPermissions() internal {
        vm.startPrank(governor);
        // Grant permissions for USDC Fleet
        for (uint256 i = 0; i < usdcArks.length; i++) {
            accessManager.grantCommanderRole(
                address(usdcArks[i]),
                address(usdcFleetCommander)
            );
        }
        accessManager.grantCommanderRole(
            address(usdcBufferArk),
            address(usdcFleetCommander)
        );

        // Grant keeper role
        accessManager.grantKeeperRole(address(usdcFleetCommander), keeper);
        vm.stopPrank();
    }

    function test_DepositRebalanceWithdraw_RoundsFleet() public {
        // Arrange
        RoundsVaultInput usdcRoundsVaultInput = new RoundsVaultInput(
            address(usdcFleetCommander),
            address(accessManager),
            "URI"
        );
        RoundsVaultOutput usdcRoundsVaultOutput = new RoundsVaultOutput(
            address(usdcFleetCommander),
            address(accessManager),
            "URI"
        );

        address usdcUser = address(0x1);

        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(usdcRoundsVaultInput), keeper);
        accessManager.grantKeeperRole(address(usdcRoundsVaultOutput), keeper);

        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(usdcRoundsVaultInput));
        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(usdcRoundsVaultOutput));
        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(usdcFleetCommander));

        usdcRoundsVaultInput.setWhitelisted(usdcUser, true);
        usdcRoundsVaultOutput.setWhitelisted(usdcUser, true);

        usdcFleetCommander.setWhitelisted(usdcUser, true);
        usdcFleetCommander.setWhitelisted(address(usdcRoundsVaultInput), true);
        usdcFleetCommander.setWhitelisted(address(usdcRoundsVaultOutput), true);
        usdcFleetCommander.setFleetTokenTransferability(true);

        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(usdcFleetCommander),
            address(usdcRoundsVaultInput)
        );
        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(usdcFleetCommander),
            address(usdcRoundsVaultOutput)
        );

        vm.stopPrank();

        uint256 usdcTotalDeposit = 1000 * 10 ** 6; // 1000 USDC

        // Set deposit caps and minimum buffer balances
        setFleetParameters(
            IFleetCommander(address(usdcFleetCommander)),
            usdcTotalDeposit,
            0
        );

        // Mint tokens for user
        deal(USDC_ADDRESS, usdcUser, usdcTotalDeposit);

        // User requests a deposit through the rounds input vault
        vm.startPrank(usdcUser);
        usdcTokenContract.approve(
            address(usdcRoundsVaultInput),
            usdcTotalDeposit
        );
        usdcRoundsVaultInput.deposit(usdcTotalDeposit, usdcUser);
        vm.stopPrank();

        // Wait for the keeper to advance and settle round 0
        vm.startPrank(keeper);
        usdcRoundsVaultInput.nextRound();
        usdcRoundsVaultInput.setRoundSettled(0);
        vm.stopPrank();

        // Exchange the receipt for shares
        vm.prank(usdcUser);
        usdcRoundsVaultInput.redeemExchangeAsset(
            0,
            usdcTotalDeposit,
            usdcUser,
            usdcUser
        );

        // Check user has shares
        uint256 userShares = usdcFleetCommander.balanceOf(usdcUser);
        assertEq(
            userShares,
            usdcTotalDeposit,
            "User should have received shares"
        );

        // Rebalance funds to Ark
        rebalanceFleet(
            IFleetCommander(address(usdcFleetCommander)),
            usdcTotalDeposit
        );

        // Advance time to simulate interest accrual
        vm.warp(block.timestamp + 30 days);

        // Check total assets
        assertTrue(
            usdcGearboxERC4626Ark.totalAssets() > 0,
            "Ark assets should have increased"
        );

        // Use the shares to request a withdrawal through rounds output vault
        vm.startPrank(usdcUser);
        usdcFleetCommander.approve(address(usdcRoundsVaultOutput), userShares);
        usdcRoundsVaultOutput.deposit(userShares, usdcUser);
        vm.stopPrank();

        // Rebalance funds back to buffer for OutputVault withdrawal
        address[] memory activeArks = usdcFleetCommander.getActiveArks();
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: activeArks[0],
            toArk: address(usdcBufferArk),
            // We use the full balance in the Ark + some margin or just use totalAssets if it empties it
            amount: usdcFleetCommander.totalAssets(),
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        usdcFleetCommander.rebalance(rebalanceData);

        // Wait for the keeper to go another 3 rounds to have unsettled rounds
        vm.startPrank(keeper);
        usdcRoundsVaultOutput.nextRound(); // Round 0 finishes, Round 1 opens
        usdcRoundsVaultOutput.nextRound(); // Round 1 finishes, Round 2 opens
        usdcRoundsVaultOutput.nextRound(); // Round 2 finishes, Round 3 opens
        vm.stopPrank();

        // Check that not settled rounds cannot redeemExchangeAsset
        vm.startPrank(usdcUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRoundsVaultBaseErrors.RoundNotSettled.selector,
                0
            )
        );
        usdcRoundsVaultOutput.redeemExchangeAsset(
            0,
            userShares,
            usdcUser,
            usdcUser
        );
        vm.stopPrank();

        // Settle the first round
        vm.prank(keeper);
        usdcRoundsVaultOutput.setRoundSettled(0);

        // Verify round 1 still reverts
        vm.startPrank(usdcUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRoundsVaultBaseErrors.RoundNotSettled.selector,
                1
            )
        );
        usdcRoundsVaultOutput.redeemExchangeAsset(
            1,
            userShares,
            usdcUser,
            usdcUser
        );
        vm.stopPrank();

        // Exchange their receipt ticket for withdrawal for the actual assets
        vm.prank(usdcUser);
        usdcRoundsVaultOutput.redeemExchangeAsset(
            0,
            userShares,
            usdcUser,
            usdcUser
        );

        // Assert
        assertTrue(
            usdcTokenContract.balanceOf(usdcUser) >= usdcTotalDeposit,
            "User should receive at least their initial deposit"
        );
        assertApproxEqAbs(
            usdcFleetCommander.totalAssets(),
            0,
            1000,
            "USDC Fleet: Total assets should be close to 0 after withdrawals"
        );
    }

    function setFleetParameters(
        IFleetCommander fleet,
        uint256 depositCap,
        uint256 minBufferBalance
    ) internal {
        FleetCommanderStorageWriter storageWriter = new FleetCommanderStorageWriter(
                address(fleet)
            );
        storageWriter.setDepositCap(depositCap);
        storageWriter.setminimumBufferBalance(minBufferBalance);
    }

    function depositForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        token.approve(address(fleet), amount);
        uint256 previewShares = fleet.previewDeposit(amount);
        uint256 gas = gasleft();
        uint256 depositedShares = fleet.deposit(amount, user);
        console.log("Gas used for deposit:", gas - gasleft());
        assertEq(
            previewShares,
            depositedShares,
            "Preview and deposited shares should be equal"
        );
        assertEq(
            fleet.balanceOf(user),
            amount,
            "User balance should be equal to deposit"
        );

        // FleetCommander transfers are disabled by default. Enable them so the user can transfer shares to the output
        // vault
        FleetCommanderWhitelist(address(usdcFleetCommander))
            .setFleetTokenTransferability(true);
        vm.stopPrank();
    }

    function withdrawForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 expectedMinimumAmount
    ) internal {
        vm.startPrank(user);
        uint256 userShares = fleet.balanceOf(user);
        uint256 userAssets = fleet.previewRedeem(userShares);
        console.log("User shares:", userShares);
        console.log("User assets:", userAssets);
        uint256 gas = gasleft();
        fleet.withdraw(userAssets, user, user);
        console.log("Gas used for withdraw:", gas - gasleft());
        assertEq(fleet.balanceOf(user), 0, "User balance should be 0");
        assertGe(
            token.balanceOf(user),
            expectedMinimumAmount,
            "User should receive at least the expected minimum assets"
        );
        vm.stopPrank();
    }

    function rebalanceFleet(IFleetCommander fleet, uint256 amount) internal {
        address[] memory arks = fleet.getActiveArks();
        FleetConfig memory config = fleet.getConfig();

        RebalanceData[] memory rebalanceData = new RebalanceData[](arks.length);
        for (uint256 i = 0; i < arks.length; i++) {
            rebalanceData[i] = RebalanceData({
                fromArk: address(config.bufferArk),
                toArk: arks[i],
                amount: amount,
                boardData: bytes(""),
                disembarkData: bytes("")
            });
        }

        // Advance time to move past cooldown window
        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleet.rebalance(rebalanceData);
    }
}
