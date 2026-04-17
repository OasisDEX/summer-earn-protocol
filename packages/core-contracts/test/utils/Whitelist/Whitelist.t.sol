// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Whitelist} from "../../../src/utils/Whitelist/Whitelist.sol";
import {NotWhitelisted} from "../../../src/utils/Whitelist/IWhitelistErrors.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

contract MockAccessManager {
    bool public mockWhitelistOpen;
    mapping(address => mapping(address => bool)) public mockWhitelisted;

    function setWhitelistOpen(bool open) external {
        mockWhitelistOpen = open;
    }

    function setWhitelisted(
        address context,
        address account,
        bool _isWhitelisted
    ) external {
        mockWhitelisted[context][account] = _isWhitelisted;
    }

    function isWhitelistOpen(address) external view returns (bool) {
        return mockWhitelistOpen;
    }

    function isWhitelisted(
        address context,
        address account
    ) external view returns (bool) {
        return mockWhitelisted[context][account];
    }
}

contract MockWhitelist is Whitelist {
    address private accessManager;

    constructor(address _accessManager) {
        accessManager = _accessManager;
    }

    function _getAccessManager() internal view override returns (address) {
        return accessManager;
    }

    function testOnlyWhitelisted(
        address context,
        address account
    ) external onlyWhitelisted(context, account) {}
}

contract WhitelistTest is Test {
    MockAccessManager public accessManager;
    MockWhitelist public whitelist;

    function setUp() public {
        accessManager = new MockAccessManager();
        whitelist = new MockWhitelist(address(accessManager));
    }

    function test_onlyWhitelisted() public {
        address context = address(this);
        address account = address(0x123);

        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, context, account)
        );
        whitelist.testOnlyWhitelisted(context, account);

        accessManager.setWhitelisted(context, account, true);
        whitelist.testOnlyWhitelisted(context, account);
    }

    function test_isWhitelisted() public {
        address context = address(this);
        address account = address(0x123);

        assertFalse(whitelist.isWhitelisted(context, account));

        accessManager.setWhitelisted(context, account, true);
        assertTrue(whitelist.isWhitelisted(context, account));
    }

    function test_isWhitelistOpen() public {
        address context = address(this);

        assertFalse(whitelist.isWhitelistOpen(context));

        accessManager.setWhitelistOpen(true);
        assertTrue(whitelist.isWhitelistOpen(context));
    }
}
