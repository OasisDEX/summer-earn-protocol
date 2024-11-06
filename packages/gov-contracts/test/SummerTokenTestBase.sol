// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";

import {EnforcedOptionParam, IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Test, console} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockSummerGovernor} from "./MockSummerGovernor.sol";

contract SummerTokenTestBase is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 public aEid = 1;
    uint32 public bEid = 2;

    SummerToken public aSummerToken;
    SummerToken public bSummerToken;

    TimelockController public timelockA;
    TimelockController public timelockB;

    address public lzEndpointA;
    address public lzEndpointB;

    address public owner = address(this);

    ProtocolAccessManager public accessManagerA;
    ProtocolAccessManager public accessManagerB;
    MockSummerGovernor public mockGovernor;

    /// @notice Initial decay rate per second (approximately 10% per year)
    /// @dev Calculated as (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9;
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;

    uint256 constant INITIAL_SUPPLY = 1000000000;

    function setUp() public virtual override {
        super.setUp();
        initializeTokenTests();
    }

    function enableTransfers() public {
        uint256 transferEnableDate = aSummerToken.transferEnableDate() + 1;
        vm.warp(transferEnableDate);
        vm.prank(summerGovernor);
        aSummerToken.enableTransfers();
        vm.prank(summerGovernor);
        bSummerToken.enableTransfers();
    }

    function initializeTokenTests() public {
        setUpEndpoints(2, LibraryType.UltraLightNode);

        mockGovernor = new MockSummerGovernor();

        lzEndpointA = address(endpoints[aEid]);
        lzEndpointB = address(endpoints[bEid]);
        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelockA = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );
        timelockB = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );

        accessManagerA = new ProtocolAccessManager(address(timelockA));
        accessManagerB = new ProtocolAccessManager(address(timelockB));
        vm.label(address(timelockA), "TimelockController A");
        vm.label(address(timelockB), "TimelockController B");

        ISummerToken.TokenParams memory tokenParamsA = ISummerToken
            .TokenParams({
                name: "SummerToken A",
                symbol: "SUMMERA",
                lzEndpoint: lzEndpointA,
                // Changed in inheriting test suites
                owner: owner,
                accessManager: address(accessManagerA),
                decayManager: address(mockGovernor),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
                governor: summerGovernor,
                transferEnableDate: block.timestamp + 1 days
            });

        ISummerToken.TokenParams memory tokenParamsB = ISummerToken
            .TokenParams({
                name: "SummerToken B",
                symbol: "SUMMERB",
                lzEndpoint: lzEndpointB,
                // Changed in inheriting test suites
                owner: owner,
                accessManager: address(accessManagerB),
                decayManager: address(mockGovernor),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
                governor: summerGovernor,
                transferEnableDate: block.timestamp + 1 days
            });

        vm.label(owner, "Owner");

        vm.startPrank(owner);
        aSummerToken = new SummerToken(tokenParamsA);
        bSummerToken = new SummerToken(tokenParamsB);
        vm.stopPrank();

        // Config and wire the tokens
        address[] memory tokens = new address[](2);
        tokens[0] = address(aSummerToken);
        tokens[1] = address(bSummerToken);

        this.wireOApps(tokens);
    }

    function changeTokensOwnership(
        address _newOwnerA,
        address _newOwnerB
    ) public {
        aSummerToken.transferOwnership(_newOwnerA);
        bSummerToken.transferOwnership(_newOwnerB);
    }
}

// Mock contract for OFT compose testing
contract OFTComposerMock {
    address public from;
    bytes32 public guid;
    bytes public message;
    address public executor;
    bytes public extraData;

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata
    ) external payable {
        from = _from;
        guid = _guid;
        message = _message;
        executor = _executor;
        extraData = _message; // We set extraData to the message for testing
    }
}
