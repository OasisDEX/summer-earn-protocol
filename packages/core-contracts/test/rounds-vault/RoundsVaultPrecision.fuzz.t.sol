// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import "forge-std/Test.sol";

import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {IRoundsVaultBaseEnums} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";

import "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

// Mock USDC
contract MockToken is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Mock Target Vault (FleetCommander / Investment Vault)
contract MockTargetVault is ERC4626 {
    // Allows us to manipulate the exchange rate organically to simulate yield/losses
    constructor(
        IERC20 underlying
    ) ERC4626(underlying) ERC20("Mock Shares", "vUSDC") {}

    // Admin function to artificially inflate vault NAV (simulate yield)
    // Send underlying token to the vault WITHOUT minting shares
    function simulateYield(uint256 amount) external {
        IERC20(asset()).transferFrom(msg.sender, address(this), amount);
    }

    // Admin function to artificially slash vault NAV (simulate loss)
    // Burn underlying token from the vault
    function simulateLoss(uint256 amount) external {
        // Just burn the asset - for standard ERC20 we'd need a burn function,
        // since we control MockToken:
        MockToken(address(asset())).transfer(address(0xdead), amount);
    }
}

contract RoundsVaultPrecisionFuzzTest is Test {
    MockToken public usdc;
    MockTargetVault public targetVault;
    RoundsVaultInput public roundsVault;
    ProtocolAccessManager public accessManager;

    address public keeper = address(0x1111);
    address public governor = address(0x2222);

    address[] public users;
    uint256 public constant NUM_USERS = 500;
    uint256 public constant NUM_ROUNDS = 10;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);

        usdc = new MockToken();
        targetVault = new MockTargetVault(usdc);

        roundsVault = new RoundsVaultInput(
            address(targetVault),
            address(accessManager),
            "https://api.example.com/receipts/{id}"
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(roundsVault), keeper);
        vm.stopPrank();

        // Turn off whitelist for ease of testing logic
        vm.startPrank(governor);
        roundsVault.setWhitelisted(address(0), true);
        vm.stopPrank();

        // Setup users
        for (uint160 i = 1; i <= NUM_USERS; i++) {
            address u = address(i + 100);
            users.push(u);
            usdc.mint(u, 100000000 * 10 ** 18);

            vm.prank(u);
            usdc.approve(address(roundsVault), type(uint256).max);
        }
    }

    // Fuzz test mass deposits and mass redemptions across multiple rounds
    function testFuzz_MassRedemptionPrecision(uint256 seed) public {
        // Bound the seed
        seed = bound(seed, 1, type(uint64).max);

        uint256 totalOrphanedDust = 0;

        for (uint256 r = 0; r < NUM_ROUNDS; r++) {
            // 1. Users deposit random amounts into the RoundsVault
            uint256 roundTotalDeposited = 0;

            for (uint256 u = 0; u < NUM_USERS; u++) {
                // Pseudo-random deposit between 1 wei and 100k USDC
                uint256 depositAmt = (uint256(
                    keccak256(abi.encode(seed, r, u))
                ) % (100000 * 10 ** 18)) + 1;

                vm.prank(users[u]);
                roundsVault.deposit(depositAmt, users[u]);

                roundTotalDeposited += depositAmt;
            }

            // Record snapshot pre-operation
            uint256 vaultSharesBefore = targetVault.balanceOf(
                address(roundsVault)
            );

            // 2. Keeper calls nextRound to bulk execute and snapshot rate
            vm.prank(keeper);
            roundsVault.nextRound();

            // Settle the round immediately so users can redeem
            vm.prank(keeper);
            roundsVault.setRoundSettled(r);

            // Record snapshot post-operation
            uint256 vaultSharesAfter = targetVault.balanceOf(
                address(roundsVault)
            );
            uint256 bulkSharesReceived = vaultSharesAfter - vaultSharesBefore;

            // 3. Simulate chaotic market shifts (Yield or Loss in target vault)
            // This ensures exchange rate varies across rounds
            usdc.mint(address(this), 100000 * 10 ** 18);
            usdc.approve(address(targetVault), type(uint256).max);
            targetVault.simulateYield(1000 * 10 ** 18); // Inject 1000 USDC yield into target to change exchange rate
            // for NEXT round

            // 4. All users redeem their receipts for this round
            uint256 totalSharesDistributedToUsers = 0;
            for (uint256 u = 0; u < NUM_USERS; u++) {
                uint256 receiptBalance = roundsVault.balanceOf(users[u], r);

                if (receiptBalance > 0) {
                    // Record share balance before redemption
                    uint256 userSharesBefore = targetVault.balanceOf(users[u]);

                    vm.prank(users[u]);
                    roundsVault.redeemExchangeAsset(
                        r,
                        receiptBalance,
                        users[u],
                        users[u]
                    );

                    uint256 userSharesAfter = targetVault.balanceOf(users[u]);
                    totalSharesDistributedToUsers += (userSharesAfter -
                        userSharesBefore);
                }
            }

            // 5. Verification Assertions
            // Assert A: The sum of shares distributed MUST NOT exceed the bulk shares received.
            assertLe(
                totalSharesDistributedToUsers,
                bulkSharesReceived,
                "Vault distributed more shares than it received!"
            );

            // Assert B: The dust retained by the vault MUST be incredibly small (at most 1 wei per user due to
            // truncation)
            uint256 roundDust = bulkSharesReceived -
                totalSharesDistributedToUsers;

            if (roundDust > NUM_USERS) {
                console.log("----- ROUND DUST BREACH -----");
                console.log("Round:", r);
                console.log("Total Deposited Assets:", roundTotalDeposited);
                console.log("Bulk Shares Received:", bulkSharesReceived);
                console.log(
                    "Total Shares Distributed:",
                    totalSharesDistributedToUsers
                );
                console.log("Round Dust:", roundDust);

                // Print exchange rate
                Price memory exRate = roundsVault.getExchangeRate(r);
                console.log("Rate Value (Shares/Quote):", exRate.quoteAmount);
                console.log("Rate Base (Assets/Base):", exRate.baseAmount);
                console.log("-----------------------------");
            }
            assertLe(
                roundDust,
                NUM_USERS,
                "Precision loss exceeds acceptable truncation limits!"
            );

            totalOrphanedDust += roundDust;
        }

        console.log("-----------------------------------------");
        console.log("Total Users:", NUM_USERS);
        console.log("Total Rounds:", NUM_ROUNDS);
        console.log("Expected Maximum Dust:", NUM_USERS * NUM_ROUNDS, "wei");
        console.log("Actual Accumulated Dust:", totalOrphanedDust, "wei");
        console.log("-----------------------------------------");
    }
}
