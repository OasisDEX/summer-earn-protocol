// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {MockOFT} from "../mocks/MockOFT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC7802OFTAdapterSetupTest} from "./ERC7802OFTAdapter.setup.t.sol";

/**
 * @title ERC7802OFTAdapter General Tests
 * @notice Tests OFT-specific functionality of ERC7802OFTAdapter
 */
contract ERC7802OFTAdapterGeneralTest is ERC7802OFTAdapterSetupTest {
    function setUp() public override {
        super.setUp();
        _configureOFTs();
        _setupOFTBalances();
    }

    /*//////////////////////////////////////////////////////////////
                        OFT MAPPING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OftForToken_InitiallyReturnsZeroAddress() public {
        ERC20Mock newToken = new ERC20Mock();
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(newToken)),
            address(0)
        );
    }

    function test_OftForToken_ReturnsMappedAddressAfterSetting() public {
        MockOFT testOft = new MockOFT(address(tokenA));

        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(testOft)
        );

        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(tokenA)),
            address(testOft)
        );
    }

    function test_SetOftForToken_RevertsForZeroTokenAddress() public {
        MockOFT testOft = new MockOFT(address(tokenA));

        vm.prank(governor);
        vm.expectRevert(ERC7802OFTAdapter.InvalidParams.selector);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(0),
            address(testOft)
        );
    }

    function test_SetOftForToken_RevertsForZeroOftAddress() public {
        vm.prank(governor);
        vm.expectRevert(ERC7802OFTAdapter.InvalidParams.selector);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(0)
        );
    }

    function test_SetOftForToken_RevertsForNonGovernor() public {
        MockOFT testOft = new MockOFT(address(tokenA));

        vm.prank(user);
        vm.expectRevert(); // Should revert with access control error
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(testOft)
        );
    }

    function test_SetOftForToken_ValidatesOftContract() public {
        // Create a contract that doesn't implement token() properly
        address invalidOft = address(new ERC20Mock()); // This won't have token() function

        vm.prank(governor);
        vm.expectRevert(ERC7802OFTAdapter.InvalidParams.selector);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            invalidOft
        );
    }

    function test_SetOftForToken_ValidatesTokenMatches() public {
        ERC20Mock wrongToken = new ERC20Mock();
        MockOFT wrongOft = new MockOFT(address(wrongToken)); // OFT for different token

        vm.prank(governor);
        vm.expectRevert(ERC7802OFTAdapter.InvalidParams.selector);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(wrongOft)
        );
    }

    function test_SetOftForToken_CanUpdateExistingMapping() public {
        MockOFT oldOft = new MockOFT(address(tokenA));
        MockOFT newOft = new MockOFT(address(tokenA));

        // Set initial mapping
        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(oldOft)
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(tokenA)),
            address(oldOft)
        );

        // Update mapping
        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(newOft)
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(tokenA)),
            address(newOft)
        );
    }

    function test_SetOftForToken_CanMapMultipleTokens() public {
        ERC20Mock token2 = new ERC20Mock();
        ERC20Mock token3 = new ERC20Mock();

        MockOFT oft2 = new MockOFT(address(token2));
        MockOFT oft3 = new MockOFT(address(token3));

        vm.startPrank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(oftA)
        );
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(token2),
            address(oft2)
        );
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(token3),
            address(oft3)
        );
        vm.stopPrank();

        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(tokenA)),
            address(oftA)
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(
                address(token2),
                address(oft2)
            )
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(
                address(token3),
                address(oft3)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetOftForToken_EmitsOftSetEvent() public {
        MockOFT newOft = new MockOFT(address(tokenA));

        vm.expectEmit(true, true, false, true);
        emit ERC7802OFTAdapter.OftSet(address(tokenA), address(newOft));

        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(tokenA),
            address(newOft)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITED FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InheritsBaseERC7802AdapterFunctionality() public {
        // Test that ERC7802OFTAdapter properly inherits from BaseERC7802Adapter
        assertTrue(
            ERC7802OFTAdapter(address(adapterA)).supportsOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET
            )
        );
        assertFalse(
            ERC7802OFTAdapter(address(adapterA)).supportsOperation(
                BridgeTypes.OperationType.MESSAGE
            )
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).LZ_ENDPOINT(),
            lzEndpointA
        );
    }

    function test_InheritsAssetSupportFunctionality() public {
        // Test that asset support works with OFT mappings
        assertTrue(
            ERC7802OFTAdapter(address(adapterA)).supportedAsset(address(tokenA))
        );

        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setAssetSupport(
            address(tokenA),
            false
        );
        assertFalse(
            ERC7802OFTAdapter(address(adapterA)).supportedAsset(address(tokenA))
        );
    }

    function test_InheritsExternalIdMappingFunctionality() public {
        // Test that external ID mapping works
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).chainToExternalId(CHAIN_ID_B),
            LZ_EID_B
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).externalIdToChainId(LZ_EID_B),
            CHAIN_ID_B
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OftMappingAndAssetSupport_WorkTogether() public {
        ERC20Mock newToken = new ERC20Mock();
        MockOFT newOft = new MockOFT(address(newToken));

        // Enable asset support
        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setAssetSupport(
            address(newToken),
            true
        );

        // Set OFT mapping
        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setOftForToken(
            address(newToken),
            address(newOft)
        );

        // Verify both work
        assertTrue(
            ERC7802OFTAdapter(address(adapterA)).supportedAsset(
                address(newToken)
            )
        );
        assertEq(
            ERC7802OFTAdapter(address(adapterA)).oftForToken(address(newToken)),
            address(newOft)
        );

        // Verify supportsAssetTransfer works
        assertTrue(
            ERC7802OFTAdapter(address(adapterA)).supportsAssetTransfer(
                CHAIN_ID_B,
                address(newToken)
            )
        );
    }

    function test_CannotTransferWithoutOftMapping() public {
        ERC20Mock tokenWithoutOft = new ERC20Mock();

        // Enable asset support but don't set OFT mapping
        vm.prank(governor);
        ERC7802OFTAdapter(address(adapterA)).setAssetSupport(
            address(tokenWithoutOft),
            true
        );

        // Give user some tokens
        tokenWithoutOft.mint(user, 100e18);

        // Try to transfer - should fail due to missing OFT
        vm.prank(user);
        tokenWithoutOft.approve(address(routerA), 100e18);
        vm.prank(user);
        tokenWithoutOft.transfer(address(routerA), 100e18);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: user,
                destinationChainId: CHAIN_ID_B,
                target: recipient,
                asset: address(tokenWithoutOft),
                amount: 100e18,
                message: "",
                refundAddress: user
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapterA),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        vm.prank(address(routerA));
        vm.expectRevert(ERC7802OFTAdapter.UnsupportedAsset.selector);
        ERC7802OFTAdapter(address(adapterA)).transferAsset("", params, options);
    }
}
