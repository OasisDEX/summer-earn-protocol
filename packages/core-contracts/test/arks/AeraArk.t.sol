// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";

import "../../src/contracts/arks/AeraArk.sol";
import "../../src/events/IArkEvents.sol";
import "../../src/interfaces/IArkWithWithdrawalRequest.sol";
import {IConfigurationManager} from "@summerfi/config-contracts/interfaces/IConfigurationManager.sol";
import {IProvisioner} from "../../src/interfaces/gauntlet/IProvisioner.sol";
import {IPriceAndFeeCalculator} from "../../src/interfaces/gauntlet/IPriceFeeCalculator.sol";
import {Request, RequestType, VaultPriceState} from "../../src/interfaces/gauntlet/Types.sol";

// Interface for Solmate Auth to get owner and authority
interface IAuth {
    function owner() external view returns (address);

    function authority() external view returns (address);
}

import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract AeraArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;

    AeraArk public ark;
    IProvisioner public provisioner;
    IPriceAndFeeCalculator public priceCalculator;
    IERC20 public usdc;
    IERC20 public vault;
    ArkParams public params;

    // Base addresses
    address public constant PROVISIONER_ADDRESS =
        0x18CF8d963E1a727F9bbF3AEffa0Bd04FB4dBdA07;
    address public constant VAULT_ADDRESS =
        0x000000000001CdB57E58Fa75Fe420a0f4D6640D5;
    address public constant USDC_ADDRESS =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base USDC

    uint256 forkBlock = 33809569; // A recent block number for Base
    uint256 forkId;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request deadline used in tests (24 hours)
    uint256 private REQUEST_DEADLINE = 0;

    /// @notice Maximum price age used in tests (1 hour)
    uint256 private MAX_PRICE_AGE = 0;

    /// @notice Default solver tip (0 for auto-price requests)
    uint256 private DEFAULT_SOLVER_TIP = 0;

    /// @notice Buffer time for expired request tests (1 hour past deadline)
    uint256 private constant EXPIRY_BUFFER = 1 hours;

    /// @notice Price increase for unit price manipulation (in BPS)
    uint256 private constant PRICE_INCREASE_BPS = 10001; // 0.01%

    address solver = address(0x999); // Mock solver address
    address provisionerOwner;
    address provisionerAuthority;
    address accountant = 0x854e4f646a73CC34e89aD9E4826f57DCB265c77b;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("base"), forkBlock);

        usdc = IERC20(USDC_ADDRESS);
        provisioner = IProvisioner(PROVISIONER_ADDRESS);
        vault = IERC20(VAULT_ADDRESS);

        // Get price calculator from provisioner
        address priceCalculatorAddr = provisioner.PRICE_FEE_CALCULATOR();
        priceCalculator = IPriceAndFeeCalculator(priceCalculatorAddr);

        // Get provisioner owner and authority for authorization
        provisionerOwner = IAuth(address(provisioner)).owner();
        provisionerAuthority = IAuth(address(provisioner)).authority();

        console.log("Provisioner owner:", provisionerOwner);
        console.log("Provisioner authority:", provisionerAuthority);

        params = ArkParams({
            name: "Base USDC Aera Ark",
            details: "Base USDC Aera Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new AeraArk(PROVISIONER_ADDRESS, params);
        REQUEST_DEADLINE = ark.REQUEST_DEADLINE();
        assertGt(
            REQUEST_DEADLINE,
            0,
            "REQUEST_DEADLINE should be greater than 0"
        );
        MAX_PRICE_AGE = ark.MAX_PRICE_AGE();
        assertGt(MAX_PRICE_AGE, 0, "MAX_PRICE_AGE should be greater than 0");
        DEFAULT_SOLVER_TIP = ark.DEFAULT_SOLVER_TIP();

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        // Make addresses persistent for the fork
        vm.makePersistent(PROVISIONER_ADDRESS);
        vm.makePersistent(VAULT_ADDRESS);
        vm.makePersistent(address(ark));
        vm.makePersistent(address(usdc));

        vm.label(PROVISIONER_ADDRESS, "Provisioner");
        vm.label(VAULT_ADDRESS, "Vault");
        vm.label(address(ark), "AeraArk");
        vm.label(address(usdc), "USDC");
        vm.label(accountant, "Accountant");
    }

    function _applySlippage(uint256 amount) internal view returns (uint256) {
        return (amount * (10000 - ark.slippage())) / 10000;
    }

    /// @notice Helper function to solve async deposit requests
    function _solveAsyncDepositRequest(
        uint256 tokensIn,
        uint256 minUnitsOut
    ) internal {
        // Create the request struct that matches what was submitted
        Request memory request = Request({
            requestType: RequestType.DEPOSIT_AUTO_PRICE,
            user: address(ark),
            units: _applySlippage(minUnitsOut),
            tokens: tokensIn,
            solverTip: DEFAULT_SOLVER_TIP,
            deadline: block.timestamp + REQUEST_DEADLINE,
            maxPriceAge: MAX_PRICE_AGE
        });

        Request[] memory requests = new Request[](1);
        requests[0] = request;

        // Use solveRequestsVault which can handle auto price requests
        // This requires authorization - use the provisioner owner
        vm.prank(provisionerOwner);
        provisioner.solveRequestsVault(usdc, requests);
    }

    /// @notice Helper function to solve async redeem requests
    function _solveAsyncRedeemRequest(
        uint256 withdrawAmount,
        uint sharesToRedeem,
        uint deadline
    ) internal {
        // After increasing the unit price, the conversion should yield enough tokens
        // to satisfy the original minTokensOut requirement
        Request memory request = Request({
            requestType: RequestType.REDEEM_AUTO_PRICE,
            user: address(ark),
            units: sharesToRedeem,
            tokens: _applySlippage(withdrawAmount), // This should now be solvable due to higher unit price
            solverTip: DEFAULT_SOLVER_TIP,
            deadline: deadline,
            maxPriceAge: MAX_PRICE_AGE
        });

        console.log("Solving redeem request:");
        console.log("  user:", request.user);
        console.log("  units:", request.units);
        console.log("  tokens:", request.tokens);
        console.log("  deadline:", request.deadline);

        Request[] memory requests = new Request[](1);
        requests[0] = request;

        // Use solveRequestsVault which can handle auto price requests
        // This requires authorization - use the provisioner owner
        vm.prank(provisionerOwner);
        provisioner.solveRequestsVault(usdc, requests);
    }

    function _solveAsyncDepositRequestWithRefund(
        uint256 tokensIn,
        uint256 minUnitsOut
    ) internal {
        Request memory request = Request({
            requestType: RequestType.DEPOSIT_AUTO_PRICE,
            user: address(ark),
            units: _applySlippage(minUnitsOut),
            tokens: tokensIn,
            solverTip: DEFAULT_SOLVER_TIP,
            deadline: block.timestamp + REQUEST_DEADLINE,
            maxPriceAge: MAX_PRICE_AGE
        });

        // 4. Fast forward past deadline to allow refund
        vm.warp(block.timestamp + REQUEST_DEADLINE + EXPIRY_BUFFER);

        // 5. Refund the request directly
        console.log("Refunding deposit request directly");
        provisioner.refundRequest(usdc, request);
    }
    function _solveAsyncRedeemRequestWithRefund(
        uint256 unitsIn,
        uint256 minTokensOut
    ) internal {
        Request memory request = Request({
            requestType: RequestType.REDEEM_AUTO_PRICE,
            user: address(ark),
            units: unitsIn,
            tokens: _applySlippage(minTokensOut),
            solverTip: DEFAULT_SOLVER_TIP,
            deadline: block.timestamp + REQUEST_DEADLINE,
            maxPriceAge: MAX_PRICE_AGE
        });

        // 3. Fast forward past deadline to expire the request
        vm.warp(block.timestamp + REQUEST_DEADLINE + EXPIRY_BUFFER);

        // 5. Refund the request directly
        console.log("Refunding redeem request directly");
        provisioner.refundRequest(usdc, request);
    }

    /// @notice Helper function to increase unit price to make redeem requests solvable
    /// @param increasePercentage Percentage to increase the price by (e.g., 110 = 10% increase)
    function _increaseUnitPrice(uint256 increasePercentage) internal {
        // Get current vault state
        (VaultPriceState memory priceState, ) = priceCalculator.getVaultState(
            address(vault)
        );

        console.log("Current unit price:", priceState.unitPrice);
        console.log("Current timestamp:", priceState.timestamp);
        console.log(
            "Current price age:",
            block.timestamp - priceState.timestamp
        );

        // Calculate new higher price
        uint128 newPrice = uint128(
            (uint256(priceState.unitPrice) * increasePercentage) / 10000
        );
        uint32 newTimestamp = uint32(block.timestamp);

        console.log("Setting new unit price:", newPrice);
        console.log("Setting new timestamp:", newTimestamp);

        // Use accountant to set higher unit price
        vm.prank(accountant);
        priceCalculator.setUnitPrice(address(vault), newPrice, newTimestamp);

        // Verify the price was updated
        (VaultPriceState memory updatedState, ) = priceCalculator.getVaultState(
            address(vault)
        );
        console.log("Updated unit price:", updatedState.unitPrice);

        require(updatedState.unitPrice == newPrice, "Price update failed");
    }

    function test_UnitPriceManipulation() public {
        // Test the unit price manipulation helper
        (VaultPriceState memory initialState, ) = priceCalculator.getVaultState(
            address(vault)
        );
        uint128 initialPrice = initialState.unitPrice;

        console.log("Initial unit price:", initialPrice);

        vm.warp(block.timestamp + MAX_PRICE_AGE);
        // Increase price by 5%
        _increaseUnitPrice(10005);

        (VaultPriceState memory updatedState, ) = priceCalculator.getVaultState(
            address(vault)
        );
        uint128 updatedPrice = updatedState.unitPrice;

        console.log("Updated unit price:", updatedPrice);

        // Verify the price increased
        assertGt(updatedPrice, initialPrice, "Price should have increased");
        assertEq(
            updatedPrice,
            (initialPrice * 10005) / 10000,
            "Price should be exactly 0.05% higher"
        );
    }

    function test_ProvisionerAddresses() public view {
        console.log(
            "Expected owner: 0xfd7cF26c01a4559038292c99Fe58b9EB94493b2C"
        );
        console.log(
            "Expected authority: 0x66C59A7819aCd5a7F4d354853CE12b06fF9eab0A"
        );
        console.log("Actual owner:", provisionerOwner);
        console.log("Actual authority:", provisionerAuthority);

        // Verify we got the expected addresses
        assertEq(
            provisionerOwner,
            0xfd7cF26c01a4559038292c99Fe58b9EB94493b2C,
            "Owner should match expected"
        );
        assertEq(
            provisionerAuthority,
            0x66C59A7819aCd5a7F4d354853CE12b06fF9eab0A,
            "Authority should match expected"
        );
    }

    function test_Constructor() public {
        // Invalid provisioner address
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidAddress(string,address)",
                "provisioner",
                address(0)
            )
        );
        ark = new AeraArk(address(0), params);

        // Valid constructor
        ark = new AeraArk(PROVISIONER_ADDRESS, params);

        assertEq(
            address(ark.provisioner()),
            PROVISIONER_ADDRESS,
            "Provisioner address should match"
        );
        assertEq(
            address(ark.vault()),
            VAULT_ADDRESS,
            "Vault address should match"
        );
        assertEq(
            address(ark.asset()),
            USDC_ADDRESS,
            "Asset address should match USDC"
        );
        assertEq(ark.name(), "Base USDC Aera Ark", "Ark name should match");
    }

    function test_Board() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC (6 decimals on Base)
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        uint256 initialVaultBalance = vault.balanceOf(address(ark));
        uint256 initialTotalAssets = ark.totalAssets();
        uint256 initialAssetsInDepositQueue = ark.assetsInDepositQueue();

        vm.expectEmit(true, true, true, true);
        emit Boarded(commander, USDC_ADDRESS, amount);

        // Board creates an async deposit request
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // After boarding, assets should be in deposit queue (pending)
        uint256 assetsInDepositQueue = ark.assetsInDepositQueue();
        assertGt(
            assetsInDepositQueue,
            initialAssetsInDepositQueue,
            "Assets should be in deposit queue after boarding"
        );

        // Calculate expected units using the same rounding as the provisioner
        // The provisioner uses Floor rounding (0) when validating deposit requests
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );

        // Solve the async deposit request
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 finalVaultBalance = vault.balanceOf(address(ark));
        uint256 finalTotalAssets = ark.totalAssets();

        assertGt(
            finalVaultBalance,
            initialVaultBalance,
            "Vault units balance should increase after solving"
        );
        assertGt(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should increase after solving"
        );

        // Assets should no longer be in deposit queue
        uint256 finalAssetsInDepositQueue = ark.assetsInDepositQueue();
        assertEq(
            finalAssetsInDepositQueue,
            0,
            "Assets should not be in deposit queue after solving"
        );
    }

    function test_TotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Before solving, total assets should include assets in deposit queue
        uint256 totalAssetsBeforeSolving = ark.totalAssets();
        assertGt(
            totalAssetsBeforeSolving,
            0,
            "Total assets should be greater than 0 after boarding"
        );

        // Calculate expected units and solve the request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 totalAssetsAfterSolving = ark.totalAssets();
        assertGt(
            totalAssetsAfterSolving,
            0,
            "Total assets should be greater than 0 after solving"
        );

        // Should be approximately equal to deposited amount (allowing for some variance)
        assertApproxEqRel(
            totalAssetsAfterSolving,
            amount,
            5e16, // 5% tolerance
            "Total assets should be approximately equal to deposited amount"
        );
    }

    function test_VaultUnitsBalance() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Before solving, vault units should be 0
        uint256 vaultUnitsBeforeSolving = vault.balanceOf(address(ark));
        assertEq(
            vaultUnitsBeforeSolving,
            0,
            "Vault units should be 0 before solving"
        );

        // Calculate expected units and solve the request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 vaultUnitsAfterSolving = vault.balanceOf(address(ark));
        assertGt(
            vaultUnitsAfterSolving,
            0,
            "Vault units should be greater than 0 after solving"
        );
    }

    function test_Harvest() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Fast forward time to potentially accrue yield
        vm.warp(block.timestamp + 30 days);

        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        // Aera vaults are auto-compounding, so no separate rewards
        assertEq(rewardTokens.length, 0, "Should return no reward tokens");
        assertEq(rewardAmounts.length, 0, "Should return no reward amounts");
    }

    function test_WithdrawableTotalAssets() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();

        // For Aera with async withdrawals, withdrawable assets represent
        // tokens that have been processed and are sitting in the contract
        console.log("Withdrawable assets:", withdrawableAssets);
        console.log("Total assets:", ark.totalAssets());

        // Initially, withdrawable assets should be 0 since everything is in vault
        assertEq(
            withdrawableAssets,
            0,
            "Withdrawable assets should be 0 initially"
        );
    }

    function test_AssetsInWithdrawalQueue() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request first
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Initially no assets in withdrawal queue
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertEq(
            assetsInQueue,
            0,
            "Initially no assets should be in withdrawal queue"
        );

        // After requesting withdrawal, assets should be in queue
        uint256 withdrawAmount = 500 * 1e6;
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawAmount);

        assetsInQueue = ark.assetsInWithdrawalQueue();
        assertGt(
            assetsInQueue,
            0,
            "Assets should be in withdrawal queue after request"
        );
        console.log("Assets in withdrawal queue after request:", assetsInQueue);
    }

    function test_ClaimWithdrawal() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request first
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Request withdrawal first
        uint256 withdrawAmount = 500 * 1e6;
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawAmount);

        // Claim withdrawal (no-op for Aera since it's automatic)
        vm.prank(keeper);
        ark.claimWithdrawal(); // Should not revert

        // Check that no claim is required
        bool claimRequired = ark.isWithdrawalClaimRequired();
        assertFalse(claimRequired, "Aera should not require manual claim");
    }

    function test_RequestWithdrawal() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request first
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Test withdrawal request
        uint256 withdrawAmount = 500 * 1e6; // Withdraw half

        vm.prank(keeper);
        vm.expectEmit();
        emit IArkWithWithdrawalRequest.WithdrawalRequested(
            withdrawAmount,
            36866333879810532229499986215110199860193588099027437356549799665242621429672
        );

        ark.requestWithdrawal(withdrawAmount);

        // Verify withdrawal request was created
        uint256 requestId = ark.withdrawalRequestId();
        console.log("Withdrawal request ID:", requestId);

        // Verify assets are in withdrawal queue
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertGt(assetsInQueue, 0, "Assets should be in withdrawal queue");
    }

    function test_MaxDeposit() public view {
        // Test the max deposit functionality from provisioner
        uint256 maxDeposit = provisioner.maxDeposit();
        console.log("Max deposit available:", maxDeposit);
        assertGt(maxDeposit, 0, "Max deposit should be greater than 0");
    }

    function test_YieldAccrual() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Solve the async deposit request first
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 initialTotalAssets = ark.totalAssets();

        // Fast forward time to accrue yield
        vm.warp(block.timestamp + 365 days);

        uint256 finalTotalAssets = ark.totalAssets();

        // Check if yield has accrued (should be >= initial due to auto-compounding)
        assertGe(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should not decrease over time"
        );

        console.log("Initial total assets:", initialTotalAssets);
        console.log("Final total assets after 1 year:", finalTotalAssets);
    }

    // function test_WithdrawUsingSwap() public {
    //     uint256 amount = 1000 * 1e6; // 1000 USDC
    //     deal(USDC_ADDRESS, commander, amount);

    //     vm.startPrank(commander);
    //     usdc.approve(address(ark), amount);
    //     ark.board(amount, bytes(""));
    //     vm.stopPrank();

    //     // Solve the async deposit request first
    //     uint256 expectedUnits = priceCalculator.convertTokenToUnits(
    //         address(vault),
    //         usdc,
    //         amount
    //     );
    //     _solveAsyncDepositRequest(amount, expectedUnits);

    //     // Test emergency swap withdrawal
    //     uint256 swapAmount = 100 * 1e6; // 100 USDC

    //     // Mock swap data (simplified for test)
    //     IArkWithWithdrawalRequest.SwapData
    //         memory swapData = IArkWithWithdrawalRequest.SwapData({
    //             router: address(0x123), // Mock router
    //             swapCalldata: abi.encodeWithSignature("swap()")
    //         });

    //     bytes memory data = abi.encode(swapData);

    //     // This would normally require whitelisted router and proper swap setup
    //     // For now, test should revert due to unwhitelisted router
    //     vm.prank(keeper);
    //     try ark.withdrawUsingSwap(swapAmount, data) {
    //         // If it succeeds, check event emission
    //         console.log("Swap withdrawal completed");
    //     } catch Error(string memory reason) {
    //         console.log("Swap withdrawal failed (expected):", reason);
    //     }
    // }

    /// @notice Test complete async withdrawal flow
    function test_CompleteAsyncWithdrawalFlow() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        // 1. Board tokens
        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Solve async deposit request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Verify vault units were received
        uint256 vaultUnits = vault.balanceOf(address(ark));
        assertGt(vaultUnits, 0, "Should have vault units after deposit");

        // 3. Request withdrawal
        uint256 withdrawAmount = 500 * 1e6;
        uint sharesToRedeem;
        uint deadline = block.timestamp + REQUEST_DEADLINE;
        if (withdrawAmount == type(uint256).max) {
            sharesToRedeem = vault.balanceOf(address(ark));
            withdrawAmount = priceCalculator.convertUnitsToTokenIfActive(
                address(vault),
                usdc,
                sharesToRedeem,
                Math.Rounding.Floor
            );
        } else {
            sharesToRedeem = priceCalculator.convertTokenToUnitsIfActive(
                address(vault),
                usdc,
                withdrawAmount,
                Math.Rounding.Ceil
            );
        }
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawAmount);

        // Verify assets are in withdrawal queue
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertGt(assetsInQueue, 0, "Assets should be in withdrawal queue");

        vm.warp(block.timestamp + MAX_PRICE_AGE);
        // 4. Increase unit price to make redeem request solvable
        _increaseUnitPrice(PRICE_INCREASE_BPS); // Increase by 0.01% to account for rounding

        // 5. Solve async redeem request
        console.log("Assets in queue before solving:", assetsInQueue);
        _solveAsyncRedeemRequest(withdrawAmount, sharesToRedeem, deadline);

        // 6. Verify withdrawal was processed
        uint256 finalAssetsInQueue = ark.assetsInWithdrawalQueue();
        console.log("Assets in queue after solving:", finalAssetsInQueue);

        // Get the redeem request hash and check if it's still pending
        (bytes32 redeemHash, uint256 redeemAmount) = ark.asyncRedeemRequest();
        bool isStillPending = provisioner.asyncRedeemHashes(redeemHash);
        console.log("Is redeem request still pending:", isStillPending);
        console.log("Redeem hash:", vm.toString(redeemHash));
        console.log("Redeem amount:", redeemAmount);

        assertEq(
            finalAssetsInQueue,
            0,
            "Assets should no longer be in withdrawal queue"
        );

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertGt(
            withdrawableAssets,
            withdrawAmount,
            "Should have withdrawable assets after redeem"
        );
    }

    /// @notice Test deposit refund scenario when request expires
    function test_DepositRefund_ExpiredRequest() public {
        uint256 depositAmount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, depositAmount);

        // Record initial state
        uint256 initialCommanderBalance = usdc.balanceOf(commander);
        uint256 initialArkBalance = usdc.balanceOf(address(ark));
        uint256 initialTotalAssets = ark.totalAssets();

        console.log("Initial commander USDC balance:", initialCommanderBalance);
        console.log("Initial ark USDC balance:", initialArkBalance);
        console.log("Initial ark total assets:", initialTotalAssets);

        // 1. Board tokens (creates async deposit request)
        vm.startPrank(commander);
        usdc.approve(address(ark), depositAmount);
        ark.board(depositAmount, bytes(""));
        vm.stopPrank();

        // Verify assets are in deposit queue
        uint256 assetsInDepositQueue = ark.assetsInDepositQueue();
        assertGt(assetsInDepositQueue, 0, "Assets should be in deposit queue");
        console.log("Assets in deposit queue:", assetsInDepositQueue);

        // Total assets should include the pending deposit
        uint256 totalAssetsAfterBoard = ark.totalAssets();
        console.log("Total assets after board:", totalAssetsAfterBoard);
        assertGt(
            totalAssetsAfterBoard,
            initialTotalAssets,
            "Total assets should increase after boarding"
        );

        // 3. Try to solve the expired request (should result in refund)
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            depositAmount,
            Math.Rounding.Floor
        );

        _solveAsyncDepositRequestWithRefund(depositAmount, expectedUnits);

        // 4. Verify refund was processed
        uint256 finalAssetsInDepositQueue = ark.assetsInDepositQueue();
        console.log(
            "Assets in deposit queue after refund:",
            finalAssetsInDepositQueue
        );
        assertEq(
            finalAssetsInDepositQueue,
            0,
            "Assets should no longer be in deposit queue"
        );

        // 5. Verify total assets continuity
        uint256 finalTotalAssets = ark.totalAssets();
        uint256 finalCommanderBalance = usdc.balanceOf(commander);
        uint256 finalArkBalance = usdc.balanceOf(address(ark));

        console.log("Final commander USDC balance:", finalCommanderBalance);
        console.log("Final ark USDC balance:", finalArkBalance);
        console.log("Final ark total assets:", finalTotalAssets);

        // Commander balance should remain unchanged (they already gave tokens to ark)
        assertEq(
            finalCommanderBalance,
            initialCommanderBalance - depositAmount,
            "Commander balance should be reduced by deposit amount"
        );

        // Ark should get the USDC back from the provisioner refund
        assertEq(
            finalArkBalance,
            depositAmount,
            "Ark should receive refunded USDC from provisioner"
        );

        // Total assets should include the refunded USDC sitting in the ark
        // This should be the same as totalAssetsAfterBoard since the pending deposit is now refunded USDC
        assertEq(
            finalTotalAssets,
            totalAssetsAfterBoard,
            "Total assets should include refunded USDC in ark balance"
        );

        // Verify no vault units were minted
        uint256 vaultUnits = vault.balanceOf(address(ark));
        assertEq(vaultUnits, 0, "No vault units should be minted after refund");
    }

    /// @notice Test deposit refund using refundRequest function directly
    function test_DepositRefund_DirectRefund() public {
        uint256 amount = 500 * 1e6; // 500 USDC
        deal(USDC_ADDRESS, commander, amount);

        // Record initial balances
        uint256 initialCommanderBalance = usdc.balanceOf(commander);
        uint256 initialTotalAssets = ark.totalAssets();

        // 1. Board tokens
        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Verify deposit is pending
        uint256 assetsInQueue = ark.assetsInDepositQueue();
        assertGt(assetsInQueue, 0, "Assets should be in deposit queue");

        // 2. Get the request details for refund
        (bytes32 depositHash, uint256 depositAmount) = ark
            .asyncDepositRequest();
        console.log("Deposit hash:", vm.toString(depositHash));
        console.log("Deposit amount:", depositAmount);

        // 3. Create request struct for refund
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );

        _solveAsyncDepositRequestWithRefund(amount, expectedUnits);

        // 6. Verify refund results
        uint256 finalAssetsInQueue = ark.assetsInDepositQueue();
        uint256 finalCommanderBalance = usdc.balanceOf(commander);
        uint256 finalTotalAssets = ark.totalAssets();

        assertEq(finalAssetsInQueue, 0, "Assets should no longer be in queue");
        assertEq(
            finalCommanderBalance,
            initialCommanderBalance - amount,
            "Commander balance should be reduced by deposit amount"
        );

        // Total assets should include the refunded USDC in the ark
        uint256 finalArkBalance = usdc.balanceOf(address(ark));
        assertEq(finalArkBalance, amount, "Ark should receive refunded USDC");
        assertGt(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should include refunded USDC"
        );
    }

    /// @notice Test withdrawal refund scenario when redeem request expires
    function test_WithdrawalRefund_ExpiredRequest() public {
        uint256 depositAmount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, depositAmount);

        // 1. First, successfully deposit and get vault units
        vm.startPrank(commander);
        usdc.approve(address(ark), depositAmount);
        ark.board(depositAmount, bytes(""));
        vm.stopPrank();

        // Solve the deposit request to get vault units
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            depositAmount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(depositAmount, expectedUnits);

        // Verify we have vault units
        uint256 vaultUnits = vault.balanceOf(address(ark));
        assertGt(vaultUnits, 0, "Should have vault units after deposit");

        // Record state before withdrawal request
        uint256 initialTotalAssets = ark.totalAssets();
        uint256 initialVaultUnits = vaultUnits;

        console.log("Initial total assets:", initialTotalAssets);
        console.log("Initial vault units:", initialVaultUnits);

        // 2. Request withdrawal
        uint256 withdrawAmount = 500 * 1e6; // Withdraw half
        vm.prank(keeper);
        ark.requestWithdrawal(withdrawAmount);

        // Verify withdrawal is pending
        uint256 assetsInWithdrawalQueue = ark.assetsInWithdrawalQueue();
        assertGt(
            assetsInWithdrawalQueue,
            0,
            "Assets should be in withdrawal queue"
        );

        // Total assets should still include the pending withdrawal
        uint256 totalAssetsAfterRequest = ark.totalAssets();
        console.log(
            "Total assets after withdrawal request:",
            totalAssetsAfterRequest
        );
        assertEq(
            totalAssetsAfterRequest,
            initialTotalAssets,
            "Total assets should remain same during pending withdrawal"
        );

        // 4. Create expired withdrawal request for refund
        uint256 sharesToRedeem = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            withdrawAmount,
            Math.Rounding.Ceil
        );

        _solveAsyncRedeemRequestWithRefund(sharesToRedeem, withdrawAmount);

        // 6. Verify refund was processed
        uint256 finalAssetsInWithdrawalQueue = ark.assetsInWithdrawalQueue();
        uint256 finalVaultUnits = vault.balanceOf(address(ark));
        uint256 finalTotalAssets = ark.totalAssets();

        console.log(
            "Final assets in withdrawal queue:",
            finalAssetsInWithdrawalQueue
        );
        console.log("Final vault units:", finalVaultUnits);
        console.log("Final total assets:", finalTotalAssets);

        // Assertions for withdrawal refund
        assertEq(
            finalAssetsInWithdrawalQueue,
            0,
            "Assets should no longer be in withdrawal queue"
        );
        assertEq(
            finalVaultUnits,
            initialVaultUnits,
            "Vault units should be restored to ark"
        );
        assertEq(
            finalTotalAssets,
            initialTotalAssets,
            "Total assets should be restored"
        );
    }

    /// @notice Test total assets continuity across multiple scenarios
    function test_TotalAssetsContinuity_MultipleScenarios() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount * 3); // Give enough for multiple operations

        uint256 initialTotalAssets = ark.totalAssets();
        console.log("Starting total assets:", initialTotalAssets);

        // Scenario 1: Successful deposit and withdrawal
        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        uint256 afterDepositAssets = ark.totalAssets();
        console.log("After successful deposit:", afterDepositAssets);
        assertGt(
            afterDepositAssets,
            initialTotalAssets,
            "Assets should increase after deposit"
        );

        // Scenario 2: Refunded deposit
        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 afterSecondBoard = ark.totalAssets();
        console.log("After second board (pending):", afterSecondBoard);

        _solveAsyncDepositRequestWithRefund(amount, expectedUnits);

        uint256 afterRefundAssets = ark.totalAssets();
        console.log("After deposit refund:", afterRefundAssets);

        // After refund: vault units (~1000) + refunded USDC (1000) ≈ 2000 total
        // Before refund: vault units (~1000) + pending deposit (1000) ≈ 2000 total
        // Total should remain approximately the same, just composition changed
        assertApproxEqAbs(
            afterRefundAssets,
            afterSecondBoard,
            1,
            "Total assets should remain same - refunded USDC replaces pending deposit"
        );

        // Final verification
        console.log("Final total assets:", ark.totalAssets());
        console.log("Commander USDC balance:", usdc.balanceOf(commander));
    }

    function test_CompleteAsyncWithdrawalFlow_MaxWithdrawal() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC
        deal(USDC_ADDRESS, commander, amount);

        // 1. Board tokens
        vm.startPrank(commander);
        usdc.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // 2. Solve async deposit request
        uint256 expectedUnits = priceCalculator.convertTokenToUnitsIfActive(
            address(vault),
            usdc,
            amount,
            Math.Rounding.Floor
        );
        _solveAsyncDepositRequest(amount, expectedUnits);

        // Verify vault units were received
        uint256 vaultUnits = vault.balanceOf(address(ark));
        assertGt(vaultUnits, 0, "Should have vault units after deposit");

        // 3. Request withdrawal
        uint256 withdrawAmount = type(uint256).max;
        uint sharesToRedeem;
        uint deadline = block.timestamp + REQUEST_DEADLINE;
        if (withdrawAmount == type(uint256).max) {
            sharesToRedeem = vault.balanceOf(address(ark));
            withdrawAmount = priceCalculator.convertUnitsToTokenIfActive(
                address(vault),
                usdc,
                sharesToRedeem,
                Math.Rounding.Floor
            );
        } else {
            sharesToRedeem = priceCalculator.convertTokenToUnitsIfActive(
                address(vault),
                usdc,
                withdrawAmount,
                Math.Rounding.Ceil
            );
        }
        vm.prank(keeper);
        ark.requestWithdrawal(type(uint256).max);

        // Verify assets are in withdrawal queue
        uint256 assetsInQueue = ark.assetsInWithdrawalQueue();
        assertGt(assetsInQueue, 0, "Assets should be in withdrawal queue");

        vm.warp(block.timestamp + MAX_PRICE_AGE);
        // 4. Increase unit price to make redeem request solvable
        _increaseUnitPrice(PRICE_INCREASE_BPS); // Increase by 0.01% to account for rounding

        // 5. Solve async redeem request
        console.log("Assets in queue before solving:", assetsInQueue);
        _solveAsyncRedeemRequest(withdrawAmount, sharesToRedeem, deadline);

        // 6. Verify withdrawal was processed
        uint256 finalAssetsInQueue = ark.assetsInWithdrawalQueue();
        console.log("Assets in queue after solving:", finalAssetsInQueue);

        // Get the redeem request hash and check if it's still pending
        (bytes32 redeemHash, uint256 redeemAmount) = ark.asyncRedeemRequest();
        bool isStillPending = provisioner.asyncRedeemHashes(redeemHash);
        console.log("Is redeem request still pending:", isStillPending);
        console.log("Redeem hash:", vm.toString(redeemHash));
        console.log("Redeem amount:", redeemAmount);

        assertEq(
            finalAssetsInQueue,
            0,
            "Assets should no longer be in withdrawal queue"
        );

        uint256 withdrawableAssets = ark.withdrawableTotalAssets();
        assertGt(
            withdrawableAssets,
            withdrawAmount,
            "Should have withdrawable assets after redeem"
        );
    }
}
