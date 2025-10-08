// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SiUSDArk.sol";
import {IInfiniFiGateway} from "../../src/interfaces/infinifi/IInfiniFiGateway.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

/**
 * @title SiUSDArkUnitTest
 * @notice Unit tests for SiUSDArk using mocked contracts
 * @dev These tests don't require forking mainnet, making them faster for CI/CD
 */
contract SiUSDArkUnitTest is Test, IArkEvents, ArkTestBase {
    SiUSDArk public ark;

    ERC20Mock public mockUSDC;
    ERC20Mock public mockIUSD;
    ERC4626Mock public mockSiUSD;
    MockInfiniFiGateway public mockGateway;

    function setUp() public {
        initializeCoreContracts();

        // Deploy mock tokens
        mockUSDC = new ERC20Mock();
        mockIUSD = new ERC20Mock();

        // Deploy mock siUSD vault (ERC4626)
        mockSiUSD = new ERC4626Mock(address(mockIUSD));

        // Deploy mock InfiniFi Gateway
        mockGateway = new MockInfiniFiGateway(
            address(mockUSDC),
            address(mockIUSD),
            address(mockSiUSD)
        );

        ArkParams memory params = ArkParams({
            name: "SiUSDArk",
            details: "USDC to siUSD Ark via InfiniFi",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockUSDC),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SiUSDArk(address(mockGateway), address(mockSiUSD), params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function test_Constructor_Success() public {
        assertEq(
            address(ark.gateway()),
            address(mockGateway),
            "Gateway address should match"
        );
        assertEq(
            address(ark.siUSD()),
            address(mockSiUSD),
            "siUSD address should match"
        );
        assertEq(
            address(ark.asset()),
            address(mockUSDC),
            "Asset should be USDC"
        );
        assertEq(ark.name(), "SiUSDArk", "Ark name should match");
    }

    function test_Constructor_InvalidGatewayAddress() public {
        ArkParams memory params = ArkParams({
            name: "SiUSDArk",
            details: "Test Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockUSDC),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidGatewayAddress()"));
        new SiUSDArk(address(0), address(mockSiUSD), params);
    }

    function test_Constructor_InvalidSiUSDAddress() public {
        ArkParams memory params = ArkParams({
            name: "SiUSDArk",
            details: "Test Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockUSDC),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidSiUSDAddress()"));
        new SiUSDArk(address(mockGateway), address(0), params);
    }

    function test_Board() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC (6 decimals)
        mockUSDC.mint(commander, amount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount);

        // Expect the Boarded event
        vm.expectEmit();
        emit Boarded(commander, address(mockUSDC), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        assertGt(ark.totalAssets(), 0, "Should have assets after boarding");
        assertGt(
            mockSiUSD.balanceOf(address(ark)),
            0,
            "Should have siUSD shares"
        );
    }

    function test_Board_MultipleDeposits() public {
        uint256 amount1 = 1000 * 10 ** 6;
        uint256 amount2 = 500 * 10 ** 6;

        mockUSDC.mint(commander, amount1 + amount2);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount1 + amount2);

        ark.board(amount1, bytes(""));
        uint256 assetsAfterFirst = ark.totalAssets();

        ark.board(amount2, bytes(""));
        uint256 assetsAfterSecond = ark.totalAssets();
        vm.stopPrank();

        assertGt(
            assetsAfterSecond,
            assetsAfterFirst,
            "Assets should increase with second deposit"
        );
        assertApproxEqAbs(
            assetsAfterSecond,
            amount1 + amount2,
            100, // Small tolerance for rounding
            "Total assets should approximately equal total deposited"
        );
    }

    function test_Disembark() public {
        // First board some assets
        uint256 boardAmount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, boardAmount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));

        uint256 totalAssetsBefore = ark.totalAssets();
        uint256 disembarkAmount = totalAssetsBefore / 2; // Withdraw half

        uint256 commanderBalanceBefore = mockUSDC.balanceOf(commander);

        // Expect the Disembarked event
        vm.expectEmit();
        emit Disembarked(commander, address(mockUSDC), disembarkAmount);

        // Act
        ark.disembark(disembarkAmount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 commanderBalanceAfter = mockUSDC.balanceOf(commander);
        uint256 totalAssetsAfter = ark.totalAssets();

        assertApproxEqAbs(
            totalAssetsAfter,
            totalAssetsBefore - disembarkAmount,
            100, // Small tolerance
            "Ark assets should decrease by disembark amount"
        );
        assertGt(
            commanderBalanceAfter,
            commanderBalanceBefore,
            "Commander should receive USDC"
        );
    }

    function test_Disembark_FullWithdrawal() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, amount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount);
        ark.board(amount, bytes(""));

        uint256 totalAssets = ark.totalAssets();

        // Act - withdraw everything
        ark.disembark(totalAssets, bytes(""));
        vm.stopPrank();

        // Assert
        assertEq(
            ark.totalAssets(),
            0,
            "Ark should have 0 assets after full withdrawal"
        );
        assertEq(
            mockSiUSD.balanceOf(address(ark)),
            0,
            "Ark should have 0 siUSD shares"
        );
        assertGt(
            mockUSDC.balanceOf(commander),
            0,
            "Commander should have received USDC"
        );
    }

    function test_TotalAssets_EmptyArk() public view {
        uint256 totalAssets = ark.totalAssets();
        assertEq(totalAssets, 0, "Empty ark should have 0 total assets");
    }

    function test_TotalAssets_AfterDeposit() public {
        uint256 amount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, amount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertApproxEqAbs(
            totalAssets,
            amount,
            100, // Small tolerance for conversion
            "Total assets should match deposited amount"
        );
    }

    function test_TotalAssets_WithYield() public {
        // Deposit
        uint256 amount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, amount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 assetsBeforeYield = ark.totalAssets();

        // Simulate yield by minting more iUSD to the siUSD vault
        // This simulates the vault earning yield
        uint256 yieldAmount = 100 * 10 ** 18; // 100 iUSD yield
        mockIUSD.mint(address(mockSiUSD), yieldAmount);

        uint256 assetsAfterYield = ark.totalAssets();

        assertGt(
            assetsAfterYield,
            assetsBeforeYield,
            "Total assets should increase due to yield"
        );
    }

    function test_Harvest() public {
        vm.prank(address(raft));
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest("");

        // siUSD auto-compounds, so harvest returns empty/zero rewards
        assertEq(rewardTokens.length, 1, "Should return 1 reward token");
        assertEq(rewardAmounts.length, 1, "Should return 1 reward amount");
        assertEq(
            rewardTokens[0],
            address(0),
            "Reward token should be zero address"
        );
        assertEq(
            rewardAmounts[0],
            0,
            "Reward amount should be 0 (auto-compounding)"
        );
    }

    function test_Harvest_OnlyRaft() public {
        // Only raft can call harvest
        vm.prank(commander);
        vm.expectRevert();
        ark.harvest("");
    }

    function test_Board_OnlyCommander() public {
        uint256 amount = 1000 * 10 ** 6;
        mockUSDC.mint(address(this), amount);

        // Non-commander trying to board should fail
        mockUSDC.approve(address(ark), amount);
        vm.expectRevert();
        ark.board(amount, bytes(""));
    }

    function test_Disembark_OnlyCommander() public {
        // Setup: commander deposits first
        uint256 amount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, amount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Non-commander trying to disembark should fail
        vm.expectRevert();
        ark.disembark(100, bytes(""));
    }

    function test_CompleteFlow() public {
        // Deposit
        uint256 depositAmount = 1000 * 10 ** 6;
        mockUSDC.mint(commander, depositAmount);

        vm.startPrank(commander);
        mockUSDC.approve(address(ark), depositAmount);
        ark.board(depositAmount, bytes(""));

        // Check balance
        uint256 totalAssets1 = ark.totalAssets();
        assertGt(totalAssets1, 0, "Should have assets after deposit");

        // Simulate yield (smaller amount to avoid rounding issues)
        mockIUSD.mint(address(mockSiUSD), 10 * 10 ** 18);

        uint256 totalAssets2 = ark.totalAssets();
        assertGt(
            totalAssets2,
            totalAssets1,
            "Assets should increase with yield"
        );

        // Withdraw a specific small amount first
        uint256 withdrawAmount = 100 * 10 ** 6; // 100 USDC
        ark.disembark(withdrawAmount, bytes(""));

        // Check remaining
        uint256 totalAssets3 = ark.totalAssets();
        assertGt(totalAssets3, 0, "Should still have assets remaining");

        // Final deposit to test complete cycle
        uint256 additionalDeposit = 200 * 10 ** 6;
        mockUSDC.mint(commander, additionalDeposit);
        mockUSDC.approve(address(ark), additionalDeposit);
        ark.board(additionalDeposit, bytes(""));

        uint256 finalAssets = ark.totalAssets();
        assertGt(
            finalAssets,
            totalAssets3,
            "Assets should increase after additional deposit"
        );

        vm.stopPrank();
    }
}

/**
 * @title MockInfiniFiGateway
 * @notice Mock implementation of InfiniFi Gateway for testing
 * @dev Simulates Gateway functions: mintAndStake, unstake, and redeem
 */
contract MockInfiniFiGateway is IInfiniFiGateway {
    IERC20 public immutable usdc;
    IERC20 public immutable iusd;
    IERC4626 public immutable siusd;

    constructor(address _usdc, address _iusd, address _siusd) {
        usdc = IERC20(_usdc);
        iusd = IERC20(_iusd);
        siusd = IERC4626(_siusd);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external override returns (uint256) {
        // Transfer USDC from sender
        usdc.transferFrom(msg.sender, address(this), _amount);

        // Mint iUSD (convert from 6 decimals to 18 decimals)
        uint256 iusdAmount = _amount * 10 ** 12;
        ERC20Mock(address(iusd)).mint(_to, iusdAmount);

        return iusdAmount;
    }

    function mintAndStake(
        address _to,
        uint256 _amount
    ) external override returns (uint256) {
        // Transfer USDC from sender
        usdc.transferFrom(msg.sender, address(this), _amount);

        // Mint iUSD (convert from 6 decimals to 18 decimals)
        uint256 iusdAmount = _amount * 10 ** 12;
        ERC20Mock(address(iusd)).mint(address(this), iusdAmount);

        // Stake to siUSD
        ERC20Mock(address(iusd)).approve(address(siusd), iusdAmount);
        siusd.deposit(iusdAmount, _to);

        return iusdAmount;
    }

    function unstake(
        address _to,
        uint256 _stakedTokens
    ) external override returns (uint256) {
        // Transfer siUSD from sender
        IERC20(address(siusd)).transferFrom(
            msg.sender,
            address(this),
            _stakedTokens
        );

        // Redeem from siUSD vault to get iUSD
        uint256 iusdAmount = siusd.redeem(_stakedTokens, _to, address(this));

        return iusdAmount;
    }

    function redeem(
        address _to,
        uint256 _amount,
        uint256 /* _minAssetsOut */
    ) external override returns (uint256) {
        // Transfer iUSD from sender
        iusd.transferFrom(msg.sender, address(this), _amount);

        // Burn iUSD
        ERC20Mock(address(iusd)).burn(address(this), _amount);

        // Return USDC (convert from 18 decimals to 6 decimals)
        uint256 usdcAmount = _amount / 10 ** 12;
        usdc.transfer(_to, usdcAmount);

        return usdcAmount;
    }
}
