// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SummerGovernorGovernorTest is SummerGovernorTestBase {
    MockERC721 public mockNFT;
    MockERC1155 public mockERC1155;

    function setUp() public override {
        super.setUp();
        mockNFT = new MockERC721("Mock NFT", "MNFT");
        mockERC1155 = new MockERC1155("uri/");
    }

    function test_OnERC721Received() public {
        // Test receiving an ERC721 token
        uint256 tokenId = 1;
        mockNFT.mint(address(this), tokenId);

        // Should revert because deposits are disabled when using timelock
        vm.expectRevert(abi.encodeWithSignature("GovernorDisabledDeposit()"));
        mockNFT.safeTransferTestFrom(
            address(this),
            address(governorA),
            tokenId,
            ""
        );
    }

    function test_OnERC1155Received() public {
        // Test receiving a single ERC1155 token
        uint256 tokenId = 1;
        uint256 amount = 1;

        // Should revert because deposits are disabled when using timelock
        vm.expectRevert(abi.encodeWithSignature("GovernorDisabledDeposit()"));
        mockERC1155.mint(address(governorA), tokenId, amount, "");
    }

    function test_OnERC1155BatchReceived() public {
        // Test receiving multiple ERC1155 tokens
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 20;

        // Should revert because deposits are disabled when using timelock
        vm.expectRevert(abi.encodeWithSignature("GovernorDisabledDeposit()"));
        mockERC1155.mintBatch(address(governorA), ids, amounts, "");
    }

    /**
     * @notice Test simple ETH relay functionality
     * @dev While direct deposits to the governor are disabled, we use vm.deal() to simulate
     * ETH that could have been received through the LayerZero endpoint. This lets us test
     * the relay functionality independently of deposit restrictions.
     */
    function test_Relay() public {
        // Force ETH into the governor (simulating funds received through LZ endpoint)
        vm.deal(address(governorA), 1 ether);

        // Create a proposal to relay funds from governor to bob
        address payable target = payable(bob);
        uint256 value = 0.5 ether;
        bytes memory data = "";

        address[] memory targets = new address[](1);
        targets[0] = address(governorA);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.relay.selector,
            target,
            value,
            data
        );

        string memory description = "Relay funds to bob";

        // Rest of the proposal flow
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        uint256 initialBalance = bob.balance;

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            bob.balance,
            initialBalance + value,
            "Transfer should send correct amount"
        );
    }

    /**
     * @notice Test ETH relay with additional call data functionality
     * @dev Similar to test_Relay, we use vm.deal() to simulate ETH in the governor
     * that could have been received through the LayerZero endpoint. This test verifies
     * that the governor can not only relay ETH but also execute arbitrary calls on the
     * target contract.
     */
    function test_RelayWithData() public {
        // Setup a mock contract that will receive the relay call
        MockReceiver mockReceiver = new MockReceiver();

        // Force ETH into the governor (simulating funds received through LZ endpoint)
        vm.deal(address(governorA), 1 ether);

        // Create relay data
        bytes memory data = abi.encodeWithSelector(
            MockReceiver.receiveCall.selector,
            "test message"
        );

        // Create proposal to call governor's relay function
        address[] memory targets = new address[](1);
        targets[0] = address(governorA);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            governorA.relay.selector,
            mockReceiver,
            0.1 ether,
            data
        );

        string memory description = "Relay with data";

        // Rest of proposal flow
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, governorA.quorum(block.timestamp - 1));
        vm.stopPrank();

        vm.prank(alice);
        aSummerToken.delegate(alice);
        advanceTimeAndBlock();

        vm.prank(alice);
        uint256 proposalId = governorA.propose(
            targets,
            values,
            calldatas,
            description
        );

        advanceTimeForVotingDelay();

        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        advanceTimeForVotingPeriod();

        bytes32 descriptionHash = keccak256(bytes(description));
        governorA.queue(targets, values, calldatas, descriptionHash);

        advanceTimeForTimelockMinDelay();

        uint256 initialBalance = address(mockReceiver).balance;

        governorA.execute(targets, values, calldatas, descriptionHash);

        assertEq(
            address(mockReceiver).balance,
            initialBalance + 0.1 ether,
            "Receiver should have received ETH"
        );

        // Verify the call data was processed
        MockReceiver receiver = MockReceiver(mockReceiver);
        assertTrue(receiver.lastCalled(), "Receiver should have been called");
        assertEq(
            receiver.lastMessage(),
            "test message",
            "Message should match"
        );
    }

    function test_GovernorDepositsDisabled() public {
        // Fund the test contract and alice
        vm.deal(address(this), 1 ether);
        vm.deal(alice, 1 ether);
        vm.deal(address(lzEndpointA), 1 ether);
        vm.deal(address(timelockA), 1 ether);

        // Test 1: Direct transfer should revert
        vm.expectRevert(IGovernor.GovernorDisabledDeposit.selector);
        (bool success, ) = address(governorA).call{value: 0.1 ether}("");

        // Test 2: Transfer from non-LayerZero endpoint should revert
        vm.prank(alice);
        vm.expectRevert(IGovernor.GovernorDisabledDeposit.selector);
        (success, ) = address(governorA).call{value: 0.1 ether}("");

        // Test 3: Transfer from LayerZero endpoint should succeed
        uint256 initialBalance = address(governorA).balance;
        vm.prank(address(lzEndpointA));
        (success, ) = address(governorA).call{value: 0.1 ether}("");
        assertTrue(success, "Transfer from endpoint should succeed");
        assertEq(
            address(governorA).balance,
            initialBalance + 0.1 ether,
            "Balance should increase when sent from endpoint"
        );

        // Test 4: Transfer from timelock should succeed
        initialBalance = address(governorA).balance;
        vm.prank(address(timelockA));
        (success, ) = address(governorA).call{value: 0.1 ether}("");
        assertTrue(success, "Transfer from timelock should succeed");
        assertEq(
            address(governorA).balance,
            initialBalance + 0.1 ether,
            "Balance should increase when sent from timelock"
        );
    }
}

contract MockReceiver {
    bool public lastCalled;
    string public lastMessage;

    receive() external payable {}

    function receiveCall(string memory message) external payable {
        lastCalled = true;
        lastMessage = message;
    }
}

contract MockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function safeTransferTestFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        _safeTransfer(from, to, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MockERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        _mintBatch(to, ids, amounts, data);
    }

    function safeTransferTestFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public returns (bytes4) {
        safeTransferFrom(from, to, id, amount, data);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function safeBatchTransferTestFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public returns (bytes4) {
        safeBatchTransferFrom(from, to, ids, amounts, data);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
