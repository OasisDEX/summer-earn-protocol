// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AssetsForwarder} from "../../../src/utils/AssetsForwarder/AssetsForwarder.sol";
import {IAssetsForwarderErrors} from "../../../src/utils/AssetsForwarder/IAssetsForwarderErrors.sol";
import {IAssetsForwarderEvents} from "../../../src/utils/AssetsForwarder/IAssetsForwarderEvents.sol";
import {NotWhitelisted} from "../../../src/utils/Whitelist/IWhitelistErrors.sol";
import {IProtocolAccessManager, ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AssetsForwarderTest is
    Test,
    IAssetsForwarderEvents,
    IAssetsForwarderErrors,
    IAccessControlErrors
{
    AssetsForwarder forwarder;
    ProtocolAccessManager accessManager;
    MockERC20 token;

    address governor = makeAddr("governor");
    address keeper = makeAddr("keeper");
    address whitelistedUser = makeAddr("whitelistedUser");
    address nonWhitelistedUser = makeAddr("nonWhitelistedUser");
    address target = makeAddr("target");
    address foundation = makeAddr("foundation");

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);

        vm.startPrank(governor);
        forwarder = new AssetsForwarder(address(accessManager));

        // Setup keeper role
        accessManager.grantKeeperRole(address(forwarder), keeper);

        // Setup whitelisted users
        forwarder.setWhitelisted(whitelistedUser, true);
        forwarder.setWhitelisted(target, true);
        vm.stopPrank();

        token = new MockERC20();
    }

    function test_forwardAsset_success() public {
        uint256 amount = 100e18;
        token.mint(whitelistedUser, amount);

        vm.startPrank(whitelistedUser);
        token.approve(address(forwarder), amount);

        vm.expectEmit(true, true, true, true, address(forwarder));
        emit AssetForwarded(whitelistedUser, target, address(token), amount);

        forwarder.forwardAsset(target, address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(target), amount);
        assertEq(token.balanceOf(whitelistedUser), 0);
    }

    function test_forwardAsset_revertIfNotWhitelisted() public {
        uint256 amount = 100e18;
        token.mint(nonWhitelistedUser, amount);

        vm.startPrank(nonWhitelistedUser);
        token.approve(address(forwarder), amount);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, nonWhitelistedUser)
        );
        forwarder.forwardAsset(target, address(token), amount);
        vm.stopPrank();
    }

    function test_sendAsset_success() public {
        uint256 amount = 100e18;
        token.mint(address(forwarder), amount);

        vm.startPrank(whitelistedUser);

        vm.expectEmit(true, true, true, true, address(forwarder));
        emit AssetSent(target, address(token), amount);

        forwarder.sendAsset(target, address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(target), amount);
        assertEq(token.balanceOf(address(forwarder)), 0);
    }

    function test_sendAsset_revertIfNotWhitelisted() public {
        uint256 amount = 100e18;
        token.mint(address(forwarder), amount);

        vm.startPrank(nonWhitelistedUser);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, nonWhitelistedUser)
        );
        forwarder.sendAsset(target, address(token), amount);
        vm.stopPrank();
    }

    function test_sweepAsset_success() public {
        uint256 amount = 100e18;
        token.mint(address(forwarder), amount);

        vm.startPrank(keeper);

        vm.expectEmit(true, true, true, true, address(forwarder));
        emit AssetSwept(keeper, address(token), amount);

        forwarder.sweepAsset(address(token), amount);
        vm.stopPrank();

        assertEq(token.balanceOf(keeper), amount);
        assertEq(token.balanceOf(address(forwarder)), 0);
    }

    function test_sweepAsset_revertIfNotKeeper() public {
        uint256 amount = 100e18;
        token.mint(address(forwarder), amount);

        vm.startPrank(nonWhitelistedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                CallerIsNotKeeper.selector,
                nonWhitelistedUser
            )
        );
        forwarder.sweepAsset(address(token), amount);
        vm.stopPrank();
    }

    function test_setWhitelisted_revertIfNotGovernor() public {
        vm.startPrank(nonWhitelistedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                CallerIsNotGovernor.selector,
                nonWhitelistedUser
            )
        );
        forwarder.setWhitelisted(nonWhitelistedUser, true);
        vm.stopPrank();
    }

    function test_setWhitelistedBatch_revertIfNotGovernor() public {
        address[] memory accounts = new address[](1);
        accounts[0] = nonWhitelistedUser;
        bool[] memory allowed = new bool[](1);
        allowed[0] = true;

        vm.startPrank(nonWhitelistedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                CallerIsNotGovernor.selector,
                nonWhitelistedUser
            )
        );
        forwarder.setWhitelistedBatch(accounts, allowed);
        vm.stopPrank();
    }

    function test_validateInputs_revertZeroAddress() public {
        vm.startPrank(whitelistedUser);

        // address(0) is not whitelisted, so this will revert with NotWhitelisted(address(0)) first
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, address(0))
        );
        forwarder.forwardAsset(address(0), address(token), 100);

        vm.expectRevert(InvalidAssetAddress.selector);
        forwarder.forwardAsset(target, address(0), 100);

        vm.expectRevert(ZeroAmount.selector);
        forwarder.forwardAsset(target, address(token), 0);

        vm.stopPrank();
    }
}
