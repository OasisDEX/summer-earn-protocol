// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RoundsVaultInput} from "../../src/contracts/rounds-vault/RoundsVaultInput.sol";
import {RoundsVaultOutput} from "../../src/contracts/rounds-vault/RoundsVaultOutput.sol";
import {ERC4626VaultMock} from "../mocks/ERC4626VaultMock.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";
import {IRoundsVaultBaseEnums} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";
import {IRoundsVaultBaseErrors} from "../../src/interfaces/rounds-vault/IRoundsVaultBaseErrors.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// [MockAccessManager and MockTargetVault remain identical to your draft]
contract MockAccessManager {
    mapping(bytes32 => mapping(address => bool)) public roles;
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return roles[role][account];
    }
    function grantRole(bytes32 role, address account) external {
        roles[role][account] = true;
    }
    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
    function isWhitelisted(address) external pure returns (bool) {
        return true;
    }
}

contract MockTargetVault is ERC20, IERC4626 {
    address public immutable underlying;
    uint256 public navNumerator = 1;
    uint256 public navDenominator = 1;

    constructor(address asset_) ERC20("Mock Shares", "vMOCK") {
        underlying = asset_;
    }
    function asset() external view override returns (address) {
        return underlying;
    }
    function totalAssets() external view override returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }
    function convertToShares(
        uint256 assets
    ) public view override returns (uint256) {
        return (assets * navNumerator) / navDenominator;
    }
    function convertToAssets(
        uint256 shares
    ) public view override returns (uint256) {
        return (shares * navDenominator) / navNumerator;
    }
    function setNAV(uint256 numerator, uint256 denominator) external {
        navNumerator = numerator;
        navDenominator = denominator;
    }
    function previewDeposit(
        uint256 assets
    ) external view override returns (uint256) {
        return convertToShares(assets);
    }
    function previewMint(
        uint256 shares
    ) external view override returns (uint256) {
        return convertToAssets(shares);
    }
    function previewWithdraw(
        uint256 assets
    ) external view override returns (uint256) {
        return convertToShares(assets);
    }
    function previewRedeem(
        uint256 shares
    ) external view override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256) {
        uint256 shares = convertToShares(assets);
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        return shares;
    }

    function mint(
        uint256 shares,
        address receiver
    ) external override returns (uint256) {
        uint256 assets = convertToAssets(shares);
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override returns (uint256) {
        uint256 shares = convertToShares(assets);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        IERC20(underlying).transfer(receiver, assets);
        return shares;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256) {
        uint256 assets = convertToAssets(shares);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        IERC20(underlying).transfer(receiver, assets);
        return assets;
    }
    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    function maxWithdraw(
        address owner
    ) external view override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }
    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }
}

contract RoundsVaultTwoPhaseSettlementTest is
    Test,
    IRoundsVaultBaseEnums,
    IRoundsVaultBaseErrors
{
    RoundsVaultInput public inputVault;
    RoundsVaultOutput public outputVault;
    MockERC20 public asset;
    MockTargetVault public targetVault;
    MockAccessManager public accessManager;

    address public keeper = address(0x1);
    address public userA = address(0xA);
    address public userB = address(0xB);
    address public userC = address(0xC);

    function setUp() public {
        asset = new MockERC20();
        asset.initialize("Mock Asset", "ASSET", 18);
        targetVault = new MockTargetVault(address(asset));
        accessManager = new MockAccessManager();

        inputVault = new RoundsVaultInput(
            address(targetVault),
            address(accessManager),
            ""
        );
        outputVault = new RoundsVaultOutput(
            address(targetVault),
            address(accessManager),
            ""
        );

        accessManager.grantRole(
            keccak256(
                abi.encodePacked(
                    ContractSpecificRoles.KEEPER_ROLE,
                    address(inputVault)
                )
            ),
            keeper
        );
        accessManager.grantRole(
            keccak256(
                abi.encodePacked(
                    ContractSpecificRoles.KEEPER_ROLE,
                    address(outputVault)
                )
            ),
            keeper
        );

        asset.mint(userA, 100000 ether);
        asset.mint(userB, 100000 ether);
        asset.mint(userC, 100000 ether);

        vm.startPrank(userA);
        asset.approve(address(inputVault), type(uint256).max);
        asset.approve(address(targetVault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(userB);
        asset.approve(address(inputVault), type(uint256).max);
        asset.approve(address(targetVault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(userC);
        asset.approve(address(inputVault), type(uint256).max);
        asset.approve(address(targetVault), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * 1. Original DOS Mitigation Test (Fixed syntax)
     */
    function test_TwoPhase_DOSMitigation() public {
        uint256 depositA = 100 ether;
        uint256 depositB = 10 ether;

        vm.prank(userA);
        inputVault.deposit(depositA, userA);
        vm.prank(keeper);
        inputVault.nextRound();

        vm.prank(userB);
        inputVault.deposit(depositB, userB);

        vm.prank(keeper);
        inputVault.setRoundSettled(0);

        assertEq(asset.balanceOf(address(targetVault)), depositA);
        assertEq(asset.balanceOf(address(inputVault)), depositB);
    }

    /**
     * 2. Original NAV Drift Test (Fixed syntax)
     */
    function test_TwoPhase_NAVDriftTolerance() public {
        uint256 sharesToDeposit = 1000 ether;
        vm.prank(userA);
        targetVault.deposit(sharesToDeposit, userA);

        vm.startPrank(userA);
        IERC20(address(targetVault)).approve(
            address(outputVault),
            type(uint256).max
        );
        outputVault.deposit(sharesToDeposit, userA);
        vm.stopPrank();

        vm.prank(keeper);
        outputVault.nextRound();

        targetVault.setNAV(10, 9); // NAV Drops 10%
        vm.prank(keeper);
        outputVault.setRoundSettled(0);

        Price memory rate = outputVault.getExchangeRate(0);
        assertEq(rate.baseAmount, 900 ether);
        assertEq(rate.quoteAmount, 1000 ether);
    }

    /**
     * 3. Multi-Round Concurrent Input (Out of Order Settlement)
     */
    function test_TwoPhase_MultiRound_Input() public {
        // Round 0
        vm.prank(userA);
        inputVault.deposit(100 ether, userA);
        vm.prank(keeper);
        inputVault.nextRound();

        // Round 1
        vm.prank(userB);
        inputVault.deposit(200 ether, userB);
        vm.prank(keeper);
        inputVault.nextRound();

        // Round 2
        vm.prank(userC);
        inputVault.deposit(300 ether, userC);
        vm.prank(keeper);
        inputVault.nextRound();

        // All 3 rounds are InSettlement. Target Vault has 0 assets.
        assertEq(asset.balanceOf(address(targetVault)), 0);

        // Settle OUT OF ORDER to prove isolation
        vm.startPrank(keeper);
        inputVault.setRoundSettled(2); // Should move exactly 300
        assertEq(asset.balanceOf(address(targetVault)), 300 ether);

        inputVault.setRoundSettled(0); // Should move exactly 100
        assertEq(asset.balanceOf(address(targetVault)), 400 ether);

        inputVault.setRoundSettled(1); // Should move exactly 200
        assertEq(asset.balanceOf(address(targetVault)), 600 ether);
        vm.stopPrank();

        // Verify state
        assertEq(
            uint256(inputVault.roundState(0)),
            uint256(RoundState.Settled)
        );
        assertEq(
            uint256(inputVault.roundState(1)),
            uint256(RoundState.Settled)
        );
        assertEq(
            uint256(inputVault.roundState(2)),
            uint256(RoundState.Settled)
        );
        assertEq(uint256(inputVault.roundState(3)), uint256(RoundState.Opened)); // Active
    }

    /**
     * 4. Multi-Round Concurrent Output with NAV Swings
     */
    function test_TwoPhase_MultiRound_Output() public {
        // Mint target shares for everyone
        vm.prank(userA);
        targetVault.deposit(100 ether, userA);
        vm.prank(userB);
        targetVault.deposit(100 ether, userB);
        vm.prank(userC);
        targetVault.deposit(100 ether, userC);

        vm.startPrank(userA);
        targetVault.approve(address(outputVault), type(uint256).max);
        outputVault.deposit(100 ether, userA);
        vm.stopPrank();
        vm.prank(keeper);
        outputVault.nextRound(); // R0 locked

        vm.startPrank(userB);
        targetVault.approve(address(outputVault), type(uint256).max);
        outputVault.deposit(100 ether, userB);
        vm.stopPrank();
        vm.prank(keeper);
        outputVault.nextRound(); // R1 locked

        vm.startPrank(userC);
        targetVault.approve(address(outputVault), type(uint256).max);
        outputVault.deposit(100 ether, userC);
        vm.stopPrank();
        vm.prank(keeper);
        outputVault.nextRound(); // R2 locked

        // Settle R0 at 1:1
        vm.prank(keeper);
        outputVault.setRoundSettled(0);
        assertEq(outputVault.getExchangeRate(0).baseAmount, 100 ether);

        // NAV skyrockets 50%
        targetVault.setNAV(10, 15);
        vm.prank(keeper);
        outputVault.setRoundSettled(1);
        assertEq(outputVault.getExchangeRate(1).baseAmount, 150 ether, "R1"); // Captured the pump!

        // NAV dumps 80%
        targetVault.setNAV(10, 2);
        vm.prank(keeper);
        outputVault.setRoundSettled(2);
        assertEq(outputVault.getExchangeRate(2).baseAmount, 20 ether, "R2"); // Absorbed the dump!
    }

    /**
     * 5. Random Fuzzer
     * Simulates a completely randomized environment of deposits, advances, settlements, and NAV changes.
     */
    function testFuzz_TwoPhase_Chaos(uint256 seed) public {
        seed = bound(seed, 1, type(uint64).max);

        uint256 nextRoundToSettle = 0;

        for (uint256 i = 0; i < 50; i++) {
            uint256 action = uint256(keccak256(abi.encode(seed, i))) % 4;

            if (action == 0) {
                // Deposit
                uint256 amt = (uint256(keccak256(abi.encode(seed, i, "amt"))) %
                    500 ether) + 1 ether;
                vm.prank(userA);
                inputVault.deposit(amt, userA);
            } else if (action == 1) {
                // Advance
                vm.prank(keeper);
                inputVault.nextRound();
            } else if (action == 2) {
                // Settle oldest pending
                if (nextRoundToSettle < inputVault.getCurrentRound()) {
                    vm.prank(keeper);
                    inputVault.setRoundSettled(nextRoundToSettle);
                    nextRoundToSettle++;
                }
            } else if (action == 3) {
                // Shift NAV (simulate target vault accumulating underlying tokens without issuing shares)
                uint256 randomYield = (uint256(
                    keccak256(abi.encode(seed, i, "yield"))
                ) % 50 ether);
                asset.mint(address(targetVault), randomYield);
                // Because MockTargetVault uses balanceOf(this) for totalAssets, minting directly inflates the share price natively!
            }
        }

        // Cleanup: Settle any remaining pending rounds to ensure the contract never gets stuck
        vm.startPrank(keeper);
        while (nextRoundToSettle < inputVault.getCurrentRound()) {
            inputVault.setRoundSettled(nextRoundToSettle);
            nextRoundToSettle++;
        }
        vm.stopPrank();

        // Final assertion: All rounds except the active one should be Settled.
        for (uint256 i = 0; i < inputVault.getCurrentRound(); i++) {
            assertEq(
                uint256(inputVault.roundState(i)),
                uint256(RoundState.Settled),
                "A round got stuck!"
            );
        }
    }
}
