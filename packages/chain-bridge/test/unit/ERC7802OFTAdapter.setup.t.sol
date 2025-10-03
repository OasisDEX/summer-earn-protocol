// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {ERC7802OFTAdapterTestHarness} from "../mocks/ERC7802OFTAdapterTestHarness.sol";
import {BaseERC7802Adapter} from "../../src/adapters/BaseERC7802Adapter.sol";
import {MockOFT} from "../mocks/MockOFT.sol";
import {BaseERC7802AdapterSetupTest} from "./BaseERC7802Adapter.setup.t.sol";

/**
 * @title ERC7802OFTAdapter Setup Test
 * @notice Setup and fixtures for ERC7802OFTAdapter tests
 */
contract ERC7802OFTAdapterSetupTest is BaseERC7802AdapterSetupTest {
    // Mock OFT contracts
    MockOFT public oftA;
    MockOFT public oftB;

    function setUp() public virtual override {
        // Deploy mock OFTs first
        oftA = new MockOFT(address(tokenA));
        oftB = new MockOFT(address(tokenB));

        // Set labels
        vm.label(address(oftA), "MockOFT_A");
        vm.label(address(oftB), "MockOFT_B");

        super.setUp();
    }

    /**
     * @notice Deploy concrete ERC7802OFTAdapter implementation
     * @dev Implements the abstract method from BaseERC7802AdapterSetupTest
     */
    function _deployAdapter(
        address registry,
        address accessManager,
        address lzEndpoint,
        uint16[] memory chains,
        uint32[] memory lzEids
    ) internal override returns (BaseERC7802Adapter) {
        return
            new ERC7802OFTAdapterTestHarness(
                registry,
                accessManager,
                lzEndpoint
            );
    }

    function _configureOFTs() internal {
        // Configure OFT mappings after adapters are deployed
        useNetworkA();
        vm.startPrank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(oftA)
        );
        vm.stopPrank();

        useNetworkB();
        vm.startPrank(governor);
        ERC7802OFTAdapter(address(adapterB)).setOftForToken(
            address(tokenB),
            address(oftB)
        );
        vm.stopPrank();

        useNetworkA();
    }

    function _setupOFTBalances() internal {
        // Give OFTs some tokens for testing
        useNetworkA();
        vm.startPrank(user);
        tokenA.approve(address(oftA), type(uint256).max);
        tokenA.transfer(address(oftA), 10000e18);
        vm.stopPrank();

        useNetworkB();
        vm.startPrank(user);
        tokenB.approve(address(oftB), type(uint256).max);
        tokenB.transfer(address(oftB), 10000e18);
        vm.stopPrank();

        useNetworkA();
    }
}
