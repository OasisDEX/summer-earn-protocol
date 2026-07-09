// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

import {AsyncFleetGateway} from "../../src/contracts/async-gateway/AsyncFleetGateway.sol";
import {IAsyncFleetGatewayErrors} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayErrors.sol";
import {IAsyncFleetGatewayEvents} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEvents.sol";
import {MockAccessManager} from "../mocks/MockAccessManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockFleet} from "./MockFleet.sol";

abstract contract AsyncFleetGatewayTestBase is
    Test,
    IAsyncFleetGatewayErrors,
    IAsyncFleetGatewayEvents
{
    AsyncFleetGateway public gateway;
    MockERC20 public assetToken;
    MockFleet public fleetMock;
    MockAccessManager public accessManager;

    address public keeper = address(0x1001);
    address public governor = address(0x1002);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public virtual {
        assetToken = new MockERC20();
        assetToken.initialize("USD Coin", "USDC", 6);

        fleetMock = new MockFleet(address(assetToken));
        accessManager = new MockAccessManager();

        gateway = new AsyncFleetGateway(
            address(fleetMock),
            address(accessManager),
            "receiptsURI"
        );

        accessManager.grantRole(
            keccak256(
                abi.encodePacked(
                    ContractSpecificRoles.KEEPER_ROLE,
                    address(gateway)
                )
            ),
            keeper
        );
        accessManager.grantRole(accessManager.GOVERNOR_ROLE(), governor);

        vm.prank(governor);
        IProtocolAccessManagerV2(address(accessManager)).setWhitelistOpen(
            address(fleetMock),
            true
        );

        // fund users
        assetToken.mint(alice, 1_000_000e6);
        assetToken.mint(bob, 1_000_000e6);
        vm.prank(alice);
        assetToken.approve(address(gateway), type(uint256).max);
        vm.prank(bob);
        assetToken.approve(address(gateway), type(uint256).max);
    }

    // ---- helpers (used from Task 5 onward) ----

    function _requestDeposit(
        address user,
        uint256 assets
    ) internal returns (uint256 epoch) {
        vm.prank(user);
        epoch = gateway.requestDeposit(assets, user, user);
    }

    function _closeAndSettleDeposit() internal returns (uint256 settledEpoch) {
        settledEpoch = gateway.currentDepositEpoch();
        vm.startPrank(keeper);
        gateway.closeDepositEpoch();
        gateway.settleDepositEpoch(settledEpoch);
        vm.stopPrank();
    }

    function _mintFleetShares(address user, uint256 shares) internal {
        // deposit enough assets into the mock fleet on behalf of `user`
        uint256 assets = fleetMock.convertToAssets(shares) + 1;
        assetToken.mint(user, assets);
        vm.startPrank(user);
        assetToken.approve(address(fleetMock), assets);
        fleetMock.deposit(assets, user);
        vm.stopPrank();
    }

    function _requestRedeem(
        address user,
        uint256 shares
    ) internal returns (uint256 epoch) {
        vm.startPrank(user);
        fleetMock.approve(address(gateway), shares);
        epoch = gateway.requestRedeem(shares, user, user);
        vm.stopPrank();
    }

    function _closeAndSettleRedeem() internal returns (uint256 settledEpoch) {
        settledEpoch = gateway.currentRedeemEpoch();
        vm.startPrank(keeper);
        gateway.closeRedeemEpoch();
        gateway.settleRedeemEpoch(settledEpoch);
        vm.stopPrank();
    }
}
