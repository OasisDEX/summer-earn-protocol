// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {FleetCommanderParams, FleetCommanderWhitelistParams} from "../../src/types/FleetCommanderTypes.sol";
import {IFlexibleTipper} from "../../src/interfaces/IFlexibleTipper.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManagerV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagerV2.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {BufferArk, ArkParams} from "../../src/contracts/arks/BufferArk.sol";
import {Percentage, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract FleetCommanderWhitelistTest is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderWhitelist public whitelistFleet;
    FleetCommanderWhitelistParams public whitelistFleetParams;
    FleetCommanderStorageWriter public whitelistFleetStorageWriter;
    address public operator = makeAddr("operator");
    address public nonWhitelistedUser = makeAddr("nonWhitelistedUser");

    function setUp() public {
        // We override accessManager to use V2 before setupBaseContracts
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

        whitelistFleetStorageWriter = new FleetCommanderStorageWriter(
            address(whitelistFleet)
        );
        harborCommand.enlistFleetCommander(address(whitelistFleet));

        // Grant Operator role to the operator address
        IProtocolAccessManagerV2(address(accessManager)).grantOperatorRole(
            address(whitelistFleet),
            operator
        );
        IProtocolAccessManagerV2(address(accessManager))
            .grantWhitelistManagerRole(address(whitelistFleet));
        accessManager.grantKeeperRole(address(whitelistFleet), keeper);
        vm.stopPrank();

        uint256 amount = 1000 * 10 ** 6;

        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser,
            true
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            operator,
            true
        );
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser2,
            true
        );
        vm.stopPrank();

        // Operator deposits for themselves and for mockUser
        mockToken.mint(operator, amount * 2);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), amount * 2);
        whitelistFleet.deposit(amount, operator);
        whitelistFleet.deposit(amount, mockUser);
        vm.stopPrank();
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transfer to a non-whitelisted user,
     * even when general transfers are disabled (transfersEnabled = false).
     */
    function test_OperatorCanBypass_TransferToNonWhitelisted_AndDisabled()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // General transfers are disabled (already set in setUp)
        assertFalse(whitelistFleet.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers to a non-whitelisted user (bypasses transferability and whitelist)
        whitelistFleet.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();

        assertEq(
            whitelistFleet.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    /**
     * @notice Test that an account with OPERATOR_ROLE can transferFrom a whitelisted user
     * to a non-whitelisted user, even when general transfers are disabled.
     */
    function test_OperatorCanBypass_TransferFromToNonWhitelisted_AndDisabled()
        public
    {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // mockUser has shares from setUp. mockUser approves operator.
        vm.startPrank(mockUser);
        whitelistFleet.approve(operator, amountToTransfer);
        vm.stopPrank();

        // General transfers are disabled (already set in setUp)
        assertFalse(whitelistFleet.transfersEnabled());

        vm.startPrank(operator);
        // Operator transfers from whitelisted mockUser to non-whitelisted user (bypasses both)
        whitelistFleet.transferFrom(
            mockUser,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();

        assertEq(
            whitelistFleet.balanceOf(nonWhitelistedUser),
            amountToTransfer
        );
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transfer to a non-whitelisted user,
     * even if transfers are enabled.
     */
    function test_NonOperator_RevertIfTransferToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        // Enable transfers for this test
        vm.prank(governor);
        whitelistFleet.setFleetTokenTransferability(true);

        // Ensure mockUser has enough balance (from setUp)
        vm.startPrank(mockUser);
        vm.expectRevert(); // Validation fails because recipient is not whitelisted
        whitelistFleet.transfer(nonWhitelistedUser, amountToTransfer);
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transferFrom to a non-whitelisted user,
     * even if transfers are enabled.
     */
    function test_NonOperator_RevertIfTransferFromToNonWhitelisted() public {
        uint256 amountToTransfer = 100 * 10 ** 6;

        address mockUser2 = makeAddr("mockUser2");
        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            mockUser2,
            true
        );
        whitelistFleet.setFleetTokenTransferability(true); // Enable transfers
        vm.stopPrank();

        // Operator deposits for mockUser2
        mockToken.mint(operator, amountToTransfer);
        vm.startPrank(operator);
        mockToken.approve(address(whitelistFleet), amountToTransfer);
        whitelistFleet.deposit(amountToTransfer, mockUser2);
        vm.stopPrank();

        // mockUser2 approves mockUser
        vm.startPrank(mockUser2);
        whitelistFleet.approve(mockUser, amountToTransfer);
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectRevert();
        // Fails because recipient (nonWhitelistedUser) is not whitelisted
        whitelistFleet.transferFrom(
            mockUser2,
            nonWhitelistedUser,
            amountToTransfer
        );
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transfer if transfers are disabled.
     */
    function test_NonOperator_RevertIfTransfersDisabled() public {
        uint256 amountToTransfer = 10 * 10 ** 6;
        address whitelistedRecipient = makeAddr("whitelistedRecipient");

        vm.prank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            whitelistedRecipient,
            true
        );
        // Transfers stay DISABLED (default)

        vm.startPrank(mockUser);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        whitelistFleet.transfer(whitelistedRecipient, amountToTransfer);
        vm.stopPrank();
    }

    /**
     * @notice Only keeper can call tip()
     */
    function test_OnlyKeeperCanCallTip() public {
        vm.startPrank(mockUser);
        vm.expectRevert();
        whitelistFleet.tip();
        vm.stopPrank();

        vm.startPrank(keeper);
        whitelistFleet.tip();
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transfer if the fleet is paused (M-05).
     */
    function test_RevertIfTransferPaused() public {
        uint256 amountToTransfer = 10 * 10 ** 6;
        address whitelistedRecipient = makeAddr("whitelistedRecipient");

        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            whitelistedRecipient,
            true
        );
        whitelistFleet.setFleetTokenTransferability(true); // Enable transfers
        whitelistFleet.pause();
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        whitelistFleet.transfer(whitelistedRecipient, amountToTransfer);
        vm.stopPrank();
    }

    /**
     * @notice Test that a normal whitelisted user CANNOT transferFrom if the fleet is paused (M-05).
     */
    function test_RevertIfTransferFromPaused() public {
        uint256 amountToTransfer = 10 * 10 ** 6;
        address whitelistedRecipient = makeAddr("whitelistedRecipient");

        vm.startPrank(mockUser);
        whitelistFleet.approve(address(this), amountToTransfer);
        vm.stopPrank();

        vm.startPrank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            whitelistedRecipient,
            true
        );
        whitelistFleet.setFleetTokenTransferability(true); // Enable transfers
        IProtocolAccessManagerV2(address(accessManager)).setWhitelisted(
            address(whitelistFleet),
            address(this),
            true
        );
        whitelistFleet.pause();
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        whitelistFleet.transferFrom(
            mockUser,
            whitelistedRecipient,
            amountToTransfer
        );
    }

    /**
     * @notice Tests that tip accrual occurs smoothly exactly once on withdrawal,
     * maintaining correct tip values and exact state calculations after our refactor
     * preventing double-invocation.
     */
    function test_Withdraw_AccruesTipExactlyOnce() public {
        uint256 amountToWithdraw = 100 * 10 ** 6;

        vm.prank(governor);
        whitelistFleet.setTipRate(PercentageUtils.fromIntegerPercentage(5));

        uint256 initialSupply = whitelistFleet.totalSupply();

        vm.warp(block.timestamp + 365 days);

        uint256 initialTipJarBalance = whitelistFleet.balanceOf(
            whitelistFleet.tipJar()
        );
        uint256 expectedTip = whitelistFleet.previewTip(
            whitelistFleet.tipJar(),
            initialSupply
        );

        assertGt(expectedTip, 0, "Expected tip should be greater than 0");

        vm.startPrank(operator);
        whitelistFleet.withdraw(amountToWithdraw, operator, operator);
        vm.stopPrank();

        uint256 finalTipJarBalance = whitelistFleet.balanceOf(
            whitelistFleet.tipJar()
        );

        assertEq(
            finalTipJarBalance - initialTipJarBalance,
            expectedTip,
            "Tip accrued should be exactly the expected preview tip"
        );
    }

    /**
     * @notice Tests that tip accrual occurs smoothly exactly once on redeem,
     * maintaining correct tip values and exact state calculations after our refactor
     * preventing double-invocation.
     */
    function test_Redeem_AccruesTipExactlyOnce() public {
        uint256 sharesToRedeem = 100 * 10 ** 6;

        vm.prank(governor);
        whitelistFleet.setTipRate(PercentageUtils.fromIntegerPercentage(5));

        uint256 initialSupply = whitelistFleet.totalSupply();

        vm.warp(block.timestamp + 365 days);

        uint256 initialTipJarBalance = whitelistFleet.balanceOf(
            whitelistFleet.tipJar()
        );
        uint256 expectedTip = whitelistFleet.previewTip(
            whitelistFleet.tipJar(),
            initialSupply
        );

        assertGt(expectedTip, 0, "Expected tip should be greater than 0");

        vm.startPrank(operator);
        whitelistFleet.redeem(sharesToRedeem, operator, operator);
        vm.stopPrank();

        uint256 finalTipJarBalance = whitelistFleet.balanceOf(
            whitelistFleet.tipJar()
        );

        assertEq(
            finalTipJarBalance - initialTipJarBalance,
            expectedTip,
            "Tip accrued should be exactly the expected preview tip"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     CONFIG NEGATIVE & CONSTRAINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertIf_UnprivilegedAccountConfiguresFleet() public {
        address unprivileged = makeAddr("unprivileged");

        vm.startPrank(unprivileged);

        // FleetCommanderConfigProviderWhitelist
        vm.expectRevert();
        whitelistFleet.addArk(address(0));

        vm.expectRevert();
        whitelistFleet.removeArk(address(0));

        vm.expectRevert();
        whitelistFleet.setArkDepositCap(address(0), 0);

        vm.expectRevert();
        whitelistFleet.setArkMaxDepositPercentageOfTVL(
            address(0),
            PercentageUtils.fromIntegerPercentage(10)
        );

        vm.expectRevert();
        whitelistFleet.setArkMaxRebalanceOutflow(address(0), 100);

        vm.expectRevert();
        whitelistFleet.setArkMaxRebalanceInflow(address(0), 100);

        vm.expectRevert();
        whitelistFleet.setMinimumBufferBalance(1);

        vm.expectRevert();
        whitelistFleet.setFleetDepositCap(1);

        vm.expectRevert();
        whitelistFleet.setMaxRebalanceOperations(1);

        vm.expectRevert();
        whitelistFleet.setFleetTokenTransferability(true);

        vm.expectRevert();
        whitelistFleet.setOperatorGatewayStatus(true);

        // FleetCommanderWhitelist (Tipper & Pausable configs)
        vm.expectRevert();
        whitelistFleet.setTipRate(PercentageUtils.fromIntegerPercentage(1));

        vm.expectRevert();
        whitelistFleet.setMinimumPauseTime(1 days);

        vm.expectRevert();
        whitelistFleet.pause();

        vm.expectRevert();
        whitelistFleet.unpause();

        vm.stopPrank();
    }

    function test_RevertIf_AddInvalidArk() public {
        vm.startPrank(governor);

        vm.expectRevert(); // FleetCommanderInvalidArkAddress
        whitelistFleet.addArk(address(0));

        address bArk = whitelistFleet.bufferArk();
        vm.expectRevert(); // FleetCommanderArkAlreadyExists
        whitelistFleet.addArk(bArk);

        vm.stopPrank();
    }

    function test_Config_Positive() public {
        ArkParams memory bParams = ArkParams({
            name: "MockArk",
            details: "MockArk details",
            accessManager: address(accessManager),
            asset: address(mockToken),
            configurationManager: address(configurationManager),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });
        BufferArk mockArk = new BufferArk(bParams, address(0));
        address ark = address(mockArk);

        vm.startPrank(governor);
        accessManager.grantCommanderRole(ark, address(whitelistFleet));
        whitelistFleet.addArk(ark);
        whitelistFleet.setFleetTokenTransferability(true);
        whitelistFleet.setOperatorGatewayStatus(false);
        vm.stopPrank();

        assertTrue(whitelistFleet.isArkActiveOrBufferArk(ark));
        assertEq(whitelistFleet.arks(0), ark);
        assertEq(whitelistFleet.getActiveArks().length, 1);
        assertEq(whitelistFleet.getActiveArks()[0], ark);
        assertTrue(whitelistFleet.transfersEnabled());
        assertFalse(whitelistFleet.getConfig().isOperatorGatewayOpen);

        // Grant curator role to caller for test
        vm.prank(governor);
        accessManager.grantCuratorRole(address(whitelistFleet), address(this));

        whitelistFleet.setArkDepositCap(ark, 100);
        assertEq(mockArk.depositCap(), 100);

        whitelistFleet.setArkMaxDepositPercentageOfTVL(
            ark,
            PercentageUtils.fromIntegerPercentage(10)
        );
        assertEq(
            Percentage.unwrap(mockArk.maxDepositPercentageOfTVL()),
            Percentage.unwrap(PercentageUtils.fromIntegerPercentage(10))
        );

        whitelistFleet.setArkMaxRebalanceOutflow(ark, 200);
        assertEq(mockArk.maxRebalanceOutflow(), 200);

        whitelistFleet.setArkMaxRebalanceInflow(ark, 300);
        assertEq(mockArk.maxRebalanceInflow(), 300);

        whitelistFleet.setMinimumBufferBalance(500);
        assertEq(whitelistFleet.getConfig().minimumBufferBalance, 500);

        whitelistFleet.setFleetDepositCap(1000);
        assertEq(whitelistFleet.getConfig().depositCap, 1000);

        whitelistFleet.setMaxRebalanceOperations(10);
        assertEq(whitelistFleet.getConfig().maxRebalanceOperations, 10);

        // Remove ark requires depositCap to be 0
        whitelistFleet.setArkDepositCap(ark, 0);

        vm.startPrank(governor);
        whitelistFleet.removeArk(ark);
        vm.stopPrank();

        assertFalse(whitelistFleet.isArkActiveOrBufferArk(ark));
        assertEq(whitelistFleet.getActiveArks().length, 0);
    }

    function test_DirectWrapperCalls_Coverage() public {
        vm.startPrank(operator);
        // We deposited "amount" for operator in setUp. Wait, operator has amount*2 minted and deposited "amount" for operator and "amount" for mockUser.
        // So operator has shares=amount.

        whitelistFleet.withdrawFromBuffer(1, operator, operator);
        whitelistFleet.redeemFromBuffer(1, operator, operator);

        // These may succeed if conditions are met. Cover them:
        whitelistFleet.withdrawFromArks(1, operator, operator);
        whitelistFleet.redeemFromArks(1, operator, operator);

        vm.stopPrank();
    }

    function test_TransferFrom_Disabled() public {
        vm.startPrank(governor);
        whitelistFleet.setFleetTokenTransferability(false);
        vm.stopPrank();

        // operator has some shares because we deposited in setup. Let's use `operator` to transfer to `mockUser2`
        vm.startPrank(operator);
        whitelistFleet.approve(mockUser2, 1);
        vm.stopPrank();

        vm.startPrank(mockUser2);
        vm.expectRevert();
        whitelistFleet.transferFrom(operator, mockUser2, 1);
        vm.stopPrank();
    }

    function test_SettersAndPause_Coverage() public {
        vm.startPrank(governor);
        whitelistFleet.setMinimumPauseTime(7 days);
        whitelistFleet.pause();

        // forward time to unpause
        vm.warp(block.timestamp + 7 days + 1);
        whitelistFleet.unpause();

        whitelistFleet.setFeeType(IFlexibleTipper.FeeType.PERFORMANCE);
        whitelistFleet.setPerformanceFeeRate(
            PercentageUtils.fromIntegerPercentage(10)
        );
        vm.stopPrank();
    }

    function test_ZeroAmount_Coverage() public {
        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.withdraw(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.redeem(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.withdrawFromBuffer(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.redeemFromBuffer(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.withdrawFromArks(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.redeemFromArks(0, operator, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.deposit(0, operator);

        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        whitelistFleet.mint(0, operator);
        vm.stopPrank();
    }

    function test_ExceedMax_Coverage() public {
        vm.startPrank(operator);

        uint256 maxDep = whitelistFleet.maxDeposit(operator);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxDeposit(address,uint256,uint256)",
                operator,
                maxDep + 1,
                maxDep
            )
        );
        whitelistFleet.deposit(maxDep + 1, operator);

        uint256 maxM = whitelistFleet.maxMint(operator);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxMint(address,uint256,uint256)",
                operator,
                maxM + 1,
                maxM
            )
        );
        whitelistFleet.mint(maxM + 1, operator);

        uint256 maxW = whitelistFleet.maxWithdraw(operator);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                operator,
                maxW + 1,
                maxW
            )
        );
        whitelistFleet.withdraw(maxW + 1, operator, operator);

        uint256 maxR = whitelistFleet.maxRedeem(operator);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxRedeem(address,uint256,uint256)",
                operator,
                maxR + 1,
                maxR
            )
        );
        whitelistFleet.redeem(maxR + 1, operator, operator);
        vm.stopPrank();
    }

    function test_Unauthorized_Coverage() public {
        vm.startPrank(mockUser2); // this user has no allowance

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                mockUser2,
                operator
            )
        );
        whitelistFleet.withdrawFromBuffer(1, mockUser2, operator);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                mockUser2,
                operator
            )
        );
        whitelistFleet.redeemFromBuffer(1, mockUser2, operator);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                mockUser2,
                operator
            )
        );
        whitelistFleet.withdrawFromArks(1, mockUser2, operator);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedRedemption(address,address)",
                mockUser2,
                operator
            )
        );
        whitelistFleet.redeemFromArks(1, mockUser2, operator);
        vm.stopPrank();
    }
}
