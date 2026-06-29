// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {FleetCommanderWhitelistParams, RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ArkMock} from "../mocks/ArkMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @notice Coverage for FleetCommanderWhitelist's rebalance machinery and ark-backed
 *         withdraw/redeem paths, which the other whitelist suites never exercise
 *         (they only use the buffer ark). Funds two real (withdrawable) ArkMocks via
 *         rebalance and drives the reallocation, buffer-adjustment, and
 *         force-disembark-from-sorted-arks logic, plus the MAX_UINT256 routing branches.
 */
contract FleetCommanderWhitelistRebalanceTest is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderWhitelist public whitelistFleet;
    FleetCommanderWhitelistParams public whitelistFleetParams;

    address public operator = makeAddr("operatorRB");
    address public buf; // buffer ark address, cached so it is never fetched after a cheatcode
    ArkMock public arkA;
    ArkMock public arkB;

    uint256 internal constant UNIT = 10 ** 6;
    uint256 internal constant DEPOSIT = 50_000 * UNIT; // buffer min is 10_000e6 → 40_000e6 excess

    function setUp() public {
        accessManager = new ProtocolAccessManagerV2(governor);
        setupBaseContracts();
        mockToken = new ERC20Mock();

        vm.startPrank(governor);
        whitelistFleetParams = FleetCommanderWhitelistParams({
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            initialMinimumBufferBalance: INITIAL_MINIMUM_FUNDS_BUFFER_BALANCE,
            initialRebalanceCooldown: INITIAL_REBALANCE_COOLDOWN,
            asset: address(mockToken),
            name: fleetName,
            symbol: "TEST-SUM",
            details: "TestFleet-details",
            initialTipRate: PercentageUtils.fromIntegerPercentage(0),
            depositCap: type(uint256).max,
            isOperatorGatewayOpen: true
        });
        whitelistFleet = new FleetCommanderWhitelist(whitelistFleetParams);
        harborCommand.enlistFleetCommander(address(whitelistFleet));

        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(whitelistFleet),
            operator
        );
        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(whitelistFleet));
        accessManager.grantKeeperRole(address(whitelistFleet), keeper);
        accessManager.grantCuratorRole(address(whitelistFleet), curator);

        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            operator,
            true
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser,
            true
        );
        vm.stopPrank();

        buf = whitelistFleet.bufferArk();

        // Two withdrawable arks, both wired to the fleet as commander.
        arkA = createMockArk(address(mockToken), type(uint256).max, false);
        arkB = createMockArk(address(mockToken), type(uint256).max, false);
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(arkA),
            address(whitelistFleet)
        );
        accessManager.grantCommanderRole(
            address(arkB),
            address(whitelistFleet)
        );
        whitelistFleet.addArk(address(arkA));
        whitelistFleet.addArk(address(arkB));
        vm.stopPrank();

        vm.prank(curator);
        whitelistFleet.setMaxRebalanceOperations(10);

        // Operator seeds the buffer with the working capital.
        mockToken.mint(operator, DEPOSIT);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), DEPOSIT);
        whitelistFleet.deposit(DEPOSIT, operator);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _one(
        address from,
        address to,
        uint256 amount
    ) internal pure returns (RebalanceData[] memory data) {
        data = new RebalanceData[](1);
        data[0] = RebalanceData({
            fromArk: from,
            toArk: to,
            amount: amount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
    }

    /// @dev Moves `amount` from the buffer into `ark` in a single keeper rebalance.
    function _seedOne(address ark, uint256 amount) internal {
        RebalanceData[] memory data = _one(buf, ark, amount);
        vm.prank(keeper);
        whitelistFleet.rebalance(data);
    }

    /// @dev Moves `a`/`b` from the buffer into arkA/arkB in a single rebalance.
    function _seedArks(uint256 a, uint256 b) internal {
        RebalanceData[] memory data = new RebalanceData[](2);
        data[0] = RebalanceData({
            fromArk: buf,
            toArk: address(arkA),
            amount: a,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        data[1] = RebalanceData({
            fromArk: buf,
            toArk: address(arkB),
            amount: b,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        vm.prank(keeper);
        whitelistFleet.rebalance(data);
    }

    function _arkOf(address ark) internal view returns (uint256) {
        return mockToken.balanceOf(ark);
    }

    function _arksTotal() internal view returns (uint256) {
        return _arkOf(address(arkA)) + _arkOf(address(arkB));
    }

    /*//////////////////////////////////////////////////////////////
                          REBALANCE - HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_Rebalance_BufferToArks_Succeeds() public {
        uint256 bufferBefore = _arkOf(buf);

        _seedArks(20_000 * UNIT, 15_000 * UNIT);

        assertEq(arkA.totalAssets(), 20_000 * UNIT);
        assertEq(arkB.totalAssets(), 15_000 * UNIT);
        assertEq(_arkOf(buf), bufferBefore - 35_000 * UNIT);
        // Total assets conserved across buffer + arks.
        assertEq(whitelistFleet.totalAssets(), DEPOSIT);
    }

    function test_Rebalance_ArkToBuffer_WithMaxUint_MovesAll() public {
        _seedOne(address(arkA), 20_000 * UNIT);
        uint256 bufferBefore = _arkOf(buf);

        // MAX_UINT256 from a non-buffer ark moves its entire balance into the buffer.
        RebalanceData[] memory data = _one(
            address(arkA),
            buf,
            Constants.MAX_UINT256
        );
        vm.prank(keeper);
        whitelistFleet.rebalance(data);

        assertEq(arkA.totalAssets(), 0);
        assertEq(_arkOf(buf), bufferBefore + 20_000 * UNIT);
    }

    function test_GetEffectiveArkDepositCap_Reflects_Caps() public {
        // depositCap is uint256.max and maxDepositPercentageOfTVL is 100%, so the
        // effective cap equals current TVL.
        assertEq(
            whitelistFleet.getEffectiveArkDepositCap(arkA),
            whitelistFleet.totalAssets()
        );

        // Lower the absolute cap and confirm it becomes the binding constraint.
        vm.prank(curator);
        whitelistFleet.setArkDepositCap(address(arkA), 123 * UNIT);
        assertEq(whitelistFleet.getEffectiveArkDepositCap(arkA), 123 * UNIT);
    }

    /*//////////////////////////////////////////////////////////////
                       WITHDRAW / REDEEM FROM ARKS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawFromArks_FullFromSingleArk() public {
        _seedArks(20_000 * UNIT, 15_000 * UNIT);

        // 10k is coverable by a single withdrawable source, so the "full from one
        // source" branch runs. (The buffer is part of the sorted withdrawable set, so
        // we assert on the amount delivered rather than a specific ark's balance.)
        uint256 before = mockToken.balanceOf(operator);
        vm.prank(operator);
        whitelistFleet.withdrawFromArks(10_000 * UNIT, operator, operator);

        assertEq(mockToken.balanceOf(operator) - before, 10_000 * UNIT);
        assertLt(_arksTotal(), 35_000 * UNIT); // funds were pulled from the arks
    }

    function test_WithdrawFromArks_PartialAcrossArks() public {
        _seedArks(20_000 * UNIT, 15_000 * UNIT);

        // 30k exceeds any single withdrawable source: one is drained, the remainder
        // pulled from the next — exercising the partial-disembark branch.
        uint256 before = mockToken.balanceOf(operator);
        vm.prank(operator);
        whitelistFleet.withdrawFromArks(30_000 * UNIT, operator, operator);

        assertEq(mockToken.balanceOf(operator) - before, 30_000 * UNIT);
        assertLt(_arksTotal(), 35_000 * UNIT);
    }

    function test_RedeemFromArks_PullsFromArks() public {
        _seedArks(20_000 * UNIT, 15_000 * UNIT);

        // 25k of shares redeemed via the ark path (spans multiple withdrawable sources).
        uint256 before = mockToken.balanceOf(operator);
        vm.prank(operator);
        whitelistFleet.redeemFromArks(25_000 * UNIT, operator, operator);

        assertEq(mockToken.balanceOf(operator) - before, 25_000 * UNIT);
        assertLt(_arksTotal(), 35_000 * UNIT);
    }

    /*//////////////////////////////////////////////////////////////
                         redeem() / withdraw() ROUTING
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_RoutesToArks_WhenSharesExceedBuffer() public {
        _seedArks(20_000 * UNIT, 15_000 * UNIT); // buffer left at 15k

        uint256 bufferShares = whitelistFleet.convertToShares(_arkOf(buf));
        uint256 shares = bufferShares + 5_000 * UNIT; // routes to _redeemFromArks

        uint256 assetsBefore = mockToken.balanceOf(operator);
        vm.prank(operator);
        whitelistFleet.redeem(shares, operator, operator);

        assertGt(mockToken.balanceOf(operator), assetsBefore);
        // Funds came out of the arks, not just the buffer.
        assertLt(_arksTotal(), 35_000 * UNIT);
    }

    function test_Withdraw_RoutesToArks_WhenAssetsExceedBuffer() public {
        _seedArks(20_000 * UNIT, 15_000 * UNIT); // buffer left at 15k
        uint256 assets = 20_000 * UNIT; // > buffer balance → _withdrawFromArks

        vm.prank(operator);
        whitelistFleet.withdraw(assets, operator, operator);

        assertLt(_arksTotal(), 35_000 * UNIT);
    }

    function test_Redeem_Max_FromBuffer() public {
        // A small whitelisted depositor's shares stay coverable by the buffer.
        mockToken.mint(mockUser, 1_000 * UNIT);
        vm.startPrank(mockUser);
        mockToken.approve(address(whitelistFleet), 1_000 * UNIT);
        whitelistFleet.deposit(1_000 * UNIT, mockUser);

        uint256 before = mockToken.balanceOf(mockUser);
        whitelistFleet.redeem(Constants.MAX_UINT256, mockUser, mockUser);
        vm.stopPrank();

        assertEq(whitelistFleet.balanceOf(mockUser), 0);
        assertEq(mockToken.balanceOf(mockUser), before + 1_000 * UNIT);
    }

    function test_Withdraw_Max_FromBuffer() public {
        mockToken.mint(mockUser, 1_000 * UNIT);
        vm.startPrank(mockUser);
        mockToken.approve(address(whitelistFleet), 1_000 * UNIT);
        whitelistFleet.deposit(1_000 * UNIT, mockUser);

        whitelistFleet.withdraw(Constants.MAX_UINT256, mockUser, mockUser);
        vm.stopPrank();

        assertEq(whitelistFleet.balanceOf(mockUser), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                 mint()
    //////////////////////////////////////////////////////////////*/

    function test_Mint_Succeeds() public {
        uint256 shares = 1_000 * UNIT;
        uint256 cost = whitelistFleet.previewMint(shares);

        mockToken.mint(operator, cost);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), cost);
        uint256 balBefore = whitelistFleet.balanceOf(operator);
        uint256 assets = whitelistFleet.mint(shares, operator);
        vm.stopPrank();

        assertEq(assets, cost);
        assertEq(whitelistFleet.balanceOf(operator) - balBefore, shares);
    }

    /*//////////////////////////////////////////////////////////////
                          REBALANCE - REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_Rebalance_RevertIf_NoOperations() public {
        RebalanceData[] memory empty = new RebalanceData[](0);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderRebalanceNoOperations()")
        );
        whitelistFleet.rebalance(empty);
    }

    function test_Rebalance_RevertIf_TooManyOperations() public {
        vm.prank(curator);
        whitelistFleet.setMaxRebalanceOperations(1);

        RebalanceData[] memory data = new RebalanceData[](2);
        data[0] = _one(buf, address(arkA), 1)[0];
        data[1] = _one(buf, address(arkB), 1)[0];

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceTooManyOperations(uint256)",
                2
            )
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_AmountZero() public {
        RebalanceData[] memory data = _one(address(arkA), address(arkB), 0);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceAmountZero(address)",
                address(arkB)
            )
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_ArkNotActive() public {
        ArkMock stray = createMockArk(
            address(mockToken),
            type(uint256).max,
            false
        );
        RebalanceData[] memory data = _one(address(arkA), address(stray), 100);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotActive(address)",
                address(stray)
            )
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_ArkDepositCapZero() public {
        vm.prank(curator);
        whitelistFleet.setArkDepositCap(address(arkB), 0);

        RebalanceData[] memory data = _one(buf, address(arkB), 1_000 * UNIT);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkDepositCapZero(address)",
                address(arkB)
            )
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_ExceedsMaxOutflow() public {
        _seedOne(address(arkA), 20_000 * UNIT);
        vm.prank(curator);
        whitelistFleet.setArkMaxRebalanceOutflow(address(arkA), 1_000 * UNIT);

        RebalanceData[] memory data = _one(
            address(arkA),
            address(arkB),
            5_000 * UNIT
        );
        vm.prank(keeper);
        vm.expectRevert(); // FleetCommanderExceedsMaxOutflow
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_ExceedsMaxInflow() public {
        _seedOne(address(arkA), 20_000 * UNIT);
        vm.prank(curator);
        whitelistFleet.setArkMaxRebalanceInflow(address(arkB), 1_000 * UNIT);

        RebalanceData[] memory data = _one(
            address(arkA),
            address(arkB),
            5_000 * UNIT
        );
        vm.prank(keeper);
        vm.expectRevert(); // FleetCommanderExceedsMaxInflow
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_EffectiveCapExceeded() public {
        vm.prank(curator);
        whitelistFleet.setArkDepositCap(address(arkB), 1_000 * UNIT);

        RebalanceData[] memory data = _one(buf, address(arkB), 5_000 * UNIT);
        vm.prank(keeper);
        vm.expectRevert(); // FleetCommanderEffectiveDepositCapExceeded
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_NoExcessFunds() public {
        // Raise the minimum above the live buffer balance → no excess to move out.
        vm.prank(curator);
        whitelistFleet.setMinimumBufferBalance(100_000 * UNIT);

        RebalanceData[] memory data = _one(buf, address(arkA), 1_000 * UNIT);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderNoExcessFunds()")
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_InsufficientBuffer() public {
        // Buffer = 50k, min = 10k → excess = 40k; moving 45k exceeds it.
        RebalanceData[] memory data = _one(buf, address(arkA), 45_000 * UNIT);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderInsufficientBuffer()")
        );
        whitelistFleet.rebalance(data);
    }

    function test_Rebalance_RevertIf_MaxUintMovingFromBuffer() public {
        RebalanceData[] memory data = _one(
            buf,
            address(arkA),
            Constants.MAX_UINT256
        );
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantUseMaxUintMovingFromBuffer()"
            )
        );
        whitelistFleet.rebalance(data);
    }
}
