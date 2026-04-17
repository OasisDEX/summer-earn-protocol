// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuartersWhitelist} from "../../src/contracts/AdmiralsQuartersWhitelist.sol";
import {FleetCommanderWhitelist} from "../../src/contracts/FleetCommanderWhitelist.sol";
import {IAdmiralsQuartersErrors} from "../../src/errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuartersEvents} from "../../src/events/IAdmiralsQuartersEvents.sol";
import {NotWhitelisted} from "../../src/utils/Whitelist/IWhitelistErrors.sol";

import {IComet} from "../../src/interfaces/compound-v3/IComet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IAggregationRouterV6} from "../../src/interfaces/1inch/IAggregationRouterV6.sol";
import {FleetCommanderInstitutionalTestBase} from "../fleets/FleetCommanderInstitutionalTestBase.sol";
import {OneInchTestHelpers} from "../helpers/OneInchTestHelpers.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";

bytes4 constant ENTER_FLEET_SELECTOR = bytes4(
    keccak256("enterFleet(address,uint256,address)")
);
bytes4 constant EXIT_FLEET_SELECTOR = bytes4(
    keccak256("exitFleet(address,uint256)")
);

contract AdmiralsQuartersWhitelistTest is
    FleetCommanderInstitutionalTestBase,
    OneInchTestHelpers
{
    using PercentageUtils for uint256;

    AdmiralsQuartersWhitelist public admiralsQuarters;

    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI_ADDRESS =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UNISWAP_USDC_DAI_V3_POOL =
        0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;
    address public constant UNISWAP_WETH_USDC_V3_POOL =
        0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable ETH_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public constant CUSDC_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant CUSDC_HOLDER =
        0x07f56A3a9868e38EAfe7C82A28b7dC51106D138A;
    address public constant AUSDC_ADDRESS =
        0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address public constant AUSDC_HOLDER =
        0xD0b00b41F3e1a8dbFf6aBA1c0B0d7e4984605010;
    address public constant USDC_4626_VAULT =
        0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address public constant USDC_4626_HOLDER =
        0x741AA7CFB2c7bF2A1E7D4dA2e3Df6a56cA4131F3;

    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    FleetCommanderWhitelist public usdcFleet;

    uint256 constant FORK_BLOCK = 20576616;

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        _setupCore();

        // Setup a single USDC fleet using the institutional base method
        usdcFleet = new FleetCommanderWhitelist(
            _fleetParams(
                USDC_ADDRESS,
                "USDC Fleet",
                "iUSDC",
                uint256(0).fromIntegerPercentage(), // 0 tip rate
                true // gateway open
            )
        );

        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(usdcFleet));

        admiralsQuarters = new AdmiralsQuartersWhitelist(
            ONE_INCH_ROUTER,
            address(configurationManager),
            address(accessManager),
            WETH
        );

        vm.startPrank(governor);
        // Grant Operator Role to AQ on the Fleet
        accessManager.grantOperatorRole(
            address(usdcFleet),
            address(admiralsQuarters)
        );

        // Grant roles for testing
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            address(this)
        );
        accessManager.grantWhitelistManagerRole(governor);
        vm.stopPrank();

        // Mint tokens for users
        deal(USDC_ADDRESS, user1, 1000e6);
        deal(USDC_ADDRESS, user2, 1000e6);

        // Approve AdmiralsQuarters to spend user tokens
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        IERC20(DAI_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();

        vm.label(address(usdcFleet), "USDC Fleet");
        vm.label(USDC_ADDRESS, "USDC");
        vm.label(DAI_ADDRESS, "DAI");
        vm.label(WETH, "WETH");
    }

    function _setWhitelisted(
        address context,
        address account,
        bool allowed
    ) internal {
        vm.prank(governor);
        accessManager.setWhitelisted(context, account, allowed);
    }

    function test_Constructor() public {
        vm.startPrank(governor);
        vm.expectRevert(abi.encodeWithSignature("InvalidRouterAddress()"));
        new AdmiralsQuartersWhitelist(
            address(0),
            address(configurationManager),
            address(accessManager),
            WETH
        );
        vm.expectRevert(
            abi.encodeWithSignature("ConfigurationManagerZeroAddress()")
        );
        new AdmiralsQuartersWhitelist(
            ONE_INCH_ROUTER,
            address(0),
            address(accessManager),
            WETH
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidNativeTokenAddress()"));
        new AdmiralsQuartersWhitelist(
            ONE_INCH_ROUTER,
            address(configurationManager),
            address(accessManager),
            address(0)
        );

        AdmiralsQuartersWhitelist aq = new AdmiralsQuartersWhitelist(
            ONE_INCH_ROUTER,
            address(configurationManager),
            address(accessManager),
            WETH
        );

        assertEq(address(aq.owner()), governor, "Owner should be the governor");
        assertEq(
            address(aq.ONE_INCH_ROUTER()),
            ONE_INCH_ROUTER,
            "OneInchRouter should be set"
        );
        assertEq(address(aq.WRAPPED_NATIVE()), WETH, "WETH should be set");
        vm.stopPrank();
    }

    function test_Deposit_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(address(0)), 1000e6)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // RevertsOnZeroAmount
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), 0)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_Withdraw_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(address(0)), 1000e6)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_Deposit_Native_RevertsInvalidAmount() public {
        deal(user1, 0.5e18);
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidNativeAmount()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), 1e18)
        );
        admiralsQuarters.multicall{value: 0.5e18}(calls);
        vm.stopPrank();
    }

    function test_Withdraw_Native_Max() public {
        uint256 ethAmount = 1e18;
        deal(user1, ethAmount);
        vm.startPrank(user1);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), ethAmount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), 0)
        );
        admiralsQuarters.multicall{value: ethAmount}(calls);
        vm.stopPrank();

        // Assert user got the ETH back minus some minimal gas maybe (if any, but this is a test so balance shouldn't change much as there's no gas deduction inside pranks generally if we don't start with tx.gasprice)
    }

    function test_Withdraw_ERC20_Max() public {
        uint256 amount = 1000e6;
        vm.startPrank(user1);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(USDC_ADDRESS), amount)
        );
        calls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(USDC_ADDRESS), 0)
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_claimMerkleRewards_RevertsInvalidRedeemer() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidRewardsRedeemer()"));

        uint256[] memory indices;
        uint256[] memory amounts;
        bytes32[][] memory proofs;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.claimMerkleRewards,
            (user1, indices, amounts, proofs, address(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_EnterFleet_RevertsWhenNotWhitelisted() public {
        vm.startPrank(user1);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            1000e6,
            user1
        );

        // User1 is not whitelisted, should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(usdcFleet),
                user1
            )
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_EnterFleet_RevertsInvalidFleetCommander() public {
        _setWhitelisted(address(0), user1, true); // this makes _revertIfNotWhitelisted pass because context doesn't match? Wait whitelist has a specific context
        // actually just whitelist user1 for address(0) to bypass whitelist check:
        _setWhitelisted(address(0), user1, true);

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(0),
            1000e6,
            user1
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_ExitFleet_RevertsWhenNotWhitelisted() public {
        vm.startPrank(user1);
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(
            EXIT_FLEET_SELECTOR,
            address(usdcFleet),
            1000e6
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                NotWhitelisted.selector,
                address(usdcFleet),
                user1
            )
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_ExitFleet_RevertsInvalidFleetCommander() public {
        _setWhitelisted(address(0), user1, true);
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidFleetCommander()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(
            EXIT_FLEET_SELECTOR,
            address(0),
            1000e6
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_Swap_Reverts() public {
        // RevertsOnInvalidToken
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(address(0)), IERC20(DAI_ADDRESS), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("InvalidToken()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(DAI_ADDRESS), IERC20(address(0)), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();

        // RevertsOnAssetMismatch
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("AssetMismatch()"));
        calls[0] = abi.encodeCall(
            admiralsQuarters.swap,
            (IERC20(DAI_ADDRESS), IERC20(DAI_ADDRESS), 1000e6, 0, new bytes(0))
        );
        admiralsQuarters.multicall(calls);
        vm.stopPrank();
    }

    function test_EnterWithETH_ExitToETH_Whitelisted() public {
        uint256 ethAmount = 1e18; // 1 ETH

        // Deal ETH to user1
        deal(user1, ethAmount);

        // whitelist user
        _setWhitelisted(address(usdcFleet), user1, true);

        // We can't enter USDC fleet with exactly ETH unless we swap, since ETH token mismatch with USDC output.
        // We'd need a WETH fleet. Let's create one.
        FleetCommanderWhitelist wethFleet = new FleetCommanderWhitelist(
            _fleetParams(
                WETH,
                "WETH Fleet",
                "iWETH",
                uint256(0).fromIntegerPercentage(),
                true
            )
        );
        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(wethFleet));
        vm.prank(governor);
        accessManager.grantOperatorRole(
            address(wethFleet),
            address(admiralsQuarters)
        );

        _setWhitelisted(address(wethFleet), user1, true);

        uint256 userEthBalanceBefore = user1.balance;

        vm.startPrank(user1);

        // First multicall: deposit ETH and enter WETH fleet
        bytes[] memory enterCalls = new bytes[](2);
        enterCalls[0] = abi.encodeCall(
            admiralsQuarters.depositTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), ethAmount)
        );
        enterCalls[1] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(wethFleet),
            ethAmount,
            user1
        );
        admiralsQuarters.multicall{value: ethAmount}(enterCalls);

        // Verify initial state after entering fleet
        uint256 userFleetShares = wethFleet.balanceOf(user1);
        assertGt(userFleetShares, 0, "User should have WETH fleet shares");
        assertEq(
            address(admiralsQuarters).balance,
            0,
            "AdmiralsQuarters should have no ETH balance"
        );

        // Second multicall: exit fleet and withdraw as ETH
        wethFleet.approve(address(admiralsQuarters), userFleetShares);
        bytes[] memory exitCalls = new bytes[](2);
        exitCalls[0] = abi.encodeWithSelector(
            EXIT_FLEET_SELECTOR,
            address(wethFleet),
            type(uint256).max
        );
        exitCalls[1] = abi.encodeCall(
            admiralsQuarters.withdrawTokens,
            (IERC20(ETH_PSEUDO_ADDRESS), 0) // 0 means withdraw all
        );
        admiralsQuarters.multicall(exitCalls);

        // Verify final state
        uint256 userEthBalanceAfter = user1.balance;
        // User should have received ETH back (minus gas costs)
        assertGt(
            userEthBalanceAfter,
            userEthBalanceBefore - ethAmount,
            "User should have received ETH back"
        );
        assertEq(
            wethFleet.balanceOf(user1),
            0,
            "User should have no fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportFromCompound() public {
        uint256 cTokenAmount = 50000e8; // cUSDC has 8 decimals

        user1 = CUSDC_HOLDER;
        _setWhitelisted(address(usdcFleet), user1, true);

        uint256 balanceBefore = IERC20(CUSDC_ADDRESS).balanceOf(user1);
        vm.startPrank(user1);

        // Approve tokens and import position
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);

        bytes[] memory importCalls = new bytes[](2);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, cTokenAmount)
        );
        importCalls[1] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            0,
            user1
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            balanceBefore - cTokenAmount - 1,
            "Should have no cUSDC left"
        );
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "User should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportFromAave() public {
        uint256 aTokenAmount = 1000e6; // aUSDC has same decimals as USDC

        _setWhitelisted(address(usdcFleet), AUSDC_HOLDER, true);

        vm.startPrank(AUSDC_HOLDER);
        uint256 initialUserBalance = IERC20(AUSDC_ADDRESS).balanceOf(
            AUSDC_HOLDER
        );
        // Approve tokens and import position
        IERC20(AUSDC_ADDRESS).approve(address(admiralsQuarters), aTokenAmount);

        bytes[] memory importCalls = new bytes[](2);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromAaveToAdmiralsQuarters,
            (AUSDC_ADDRESS, aTokenAmount)
        );
        importCalls[1] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            0,
            AUSDC_HOLDER
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(AUSDC_ADDRESS).balanceOf(AUSDC_HOLDER),
            initialUserBalance - aTokenAmount - 1,
            "Should have no aUSDC left"
        );
        assertGt(
            usdcFleet.balanceOf(AUSDC_HOLDER),
            0,
            "User should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportFromERC4626() public {
        user1 = USDC_4626_HOLDER;
        uint256 sharesToRedeem = 1000e6; // Assuming same decimals as USDC
        _setWhitelisted(address(usdcFleet), user1, true);

        uint256 sharesAmountBefore = IERC4626(USDC_4626_VAULT).balanceOf(user1);

        vm.startPrank(user1);

        // Approve tokens and import position
        IERC20(USDC_4626_VAULT).approve(
            address(admiralsQuarters),
            sharesToRedeem
        );

        bytes[] memory importCalls = new bytes[](2);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromERC4626ToAdmiralsQuarters,
            (USDC_4626_VAULT, sharesToRedeem)
        );
        importCalls[1] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            0,
            address(user1)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(user1),
            sharesAmountBefore - sharesToRedeem,
            "Should have less shares left"
        );
        assertEq(
            IERC20(USDC_ADDRESS).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC left"
        );
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(address(admiralsQuarters)),
            0,
            "AdmiralsQuarters should have no USDC 4626 vault tokens left"
        );
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "User should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportAll_Multicall() public {
        // Deal tokens to user
        uint256 cTokenAmount = 50000e8;
        uint256 aTokenAmount = 1000e6;
        uint256 vaultSharesAmount = 1000e6;

        user1 = CUSDC_HOLDER;
        vm.prank(AUSDC_HOLDER);
        IERC20(AUSDC_ADDRESS).transfer(user1, aTokenAmount);
        vm.prank(USDC_4626_HOLDER);
        IERC20(USDC_4626_VAULT).transfer(user1, vaultSharesAmount);

        uint256 erc4626sharesBefore = IERC4626(USDC_4626_VAULT).balanceOf(
            user1
        );
        uint256 aTokenBefore = IERC20(AUSDC_ADDRESS).balanceOf(user1);
        uint256 cTokenBefore = IERC20(CUSDC_ADDRESS).balanceOf(user1);

        _setWhitelisted(address(usdcFleet), user1, true);

        vm.startPrank(user1);

        // Approve all tokens
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);
        IERC20(AUSDC_ADDRESS).approve(address(admiralsQuarters), aTokenAmount);
        IERC20(USDC_4626_VAULT).approve(
            address(admiralsQuarters),
            vaultSharesAmount
        );

        // Import all positions in one multicall
        bytes[] memory importCalls = new bytes[](4);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, cTokenAmount)
        );
        importCalls[1] = abi.encodeCall(
            admiralsQuarters.moveFromAaveToAdmiralsQuarters,
            (AUSDC_ADDRESS, aTokenAmount)
        );
        importCalls[2] = abi.encodeCall(
            admiralsQuarters.moveFromERC4626ToAdmiralsQuarters,
            (USDC_4626_VAULT, vaultSharesAmount)
        );
        importCalls[3] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            0,
            address(user1)
        );

        admiralsQuarters.multicall(importCalls);

        // Verify results
        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            cTokenBefore - cTokenAmount - 1,
            "Should have less cUSDC left"
        );
        assertEq(
            IERC20(AUSDC_ADDRESS).balanceOf(user1),
            aTokenBefore - aTokenAmount - 1,
            "Should have less aUSDC left"
        );
        assertEq(
            IERC20(USDC_4626_VAULT).balanceOf(user1),
            erc4626sharesBefore - vaultSharesAmount,
            "Should have less shares left"
        );
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportZeroAmount() public {
        // Test importing with amount = 0 (should import full balance)
        user1 = CUSDC_HOLDER;
        _setWhitelisted(address(usdcFleet), user1, true);
        vm.startPrank(user1);
        IComet(CUSDC_ADDRESS).allow(address(admiralsQuarters), true);

        bytes[] memory importCalls = new bytes[](2);
        importCalls[0] = abi.encodeCall(
            admiralsQuarters.moveFromCompoundToAdmiralsQuarters,
            (CUSDC_ADDRESS, 0)
        );
        importCalls[1] = abi.encodeWithSelector(
            ENTER_FLEET_SELECTOR,
            address(usdcFleet),
            0,
            address(user1)
        );
        admiralsQuarters.multicall(importCalls);

        assertEq(
            IERC20(CUSDC_ADDRESS).balanceOf(user1),
            0,
            "Should have imported all cUSDC"
        );
        assertGt(
            usdcFleet.balanceOf(user1),
            0,
            "Should have USDC fleet shares"
        );

        vm.stopPrank();
    }

    function test_ImportReverts() public {
        vm.startPrank(user1);

        // Test invalid token addresses
        // Since safeTransferFrom or standard operations on 0x0 will fail.
        vm.expectRevert();
        admiralsQuarters.moveFromCompoundToAdmiralsQuarters(address(0), 1000);

        vm.expectRevert();
        admiralsQuarters.moveFromAaveToAdmiralsQuarters(address(0), 1000);

        vm.expectRevert();
        admiralsQuarters.moveFromERC4626ToAdmiralsQuarters(address(0), 1000);

        // Test insufficient balance (using CUSDC_ADDRESS on user1 which has 0)
        vm.expectRevert();
        admiralsQuarters.moveFromCompoundToAdmiralsQuarters(
            CUSDC_ADDRESS,
            1000
        );

        vm.stopPrank();
    }

    function test_ProtectedMulticall_RevertsWhenDirectCall() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("NotMulticall()"));
        // Direct call to enterFleet should revert
        admiralsQuarters.enterFleet(address(usdcFleet), 100e6, user1);
        vm.stopPrank();
    }

    function test_ProtectedMulticall_RevertsWhenNestedMulticall() public {
        vm.startPrank(user1);
        bytes[] memory nestedCalls = new bytes[](0);
        bytes[] memory mainCalls = new bytes[](1);
        mainCalls[0] = abi.encodeCall(
            admiralsQuarters.multicall,
            (nestedCalls)
        );

        vm.expectRevert(
            abi.encodeWithSignature("MulticallAlreadyInProgress()")
        );
        admiralsQuarters.multicall(mainCalls);
        vm.stopPrank();
    }
}
