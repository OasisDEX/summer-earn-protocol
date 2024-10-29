// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../src/contracts/SummerToken.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";

import {EnforcedOptionParam, IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Test, console} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {MockConfigurationManager} from "./MockConfigurationManager.sol";
contract SummerTokenTestBase is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 public aEid = 1;
    uint32 public bEid = 2;

    SummerToken public aSummerToken;
    SummerToken public bSummerToken;

    address public lzEndpointA;
    address public lzEndpointB;

    address public owner = address(this);
    address public rewardsManagerA = address(0xA);
    address public rewardsManagerB = address(0xB);
    MockConfigurationManager public mockConfigurationManagerA;
    MockConfigurationManager public mockConfigurationManagerB;

    /// @notice Initial decay rate per second (approximately 10% per year)
    /// @dev Calculated as (0.1e18 / (365 * 24 * 60 * 60))
    uint256 internal constant INITIAL_DECAY_RATE_PER_SECOND = 3.1709792e9;
    uint40 public constant INITIAL_DECAY_FREE_WINDOW = 30 days;

    uint256 constant INITIAL_SUPPLY = 1000000000;

    function setUp() public virtual override {
        super.setUp();
        initializeTokenTests();
    }

    function initializeTokenTests() public {
        setUpEndpoints(2, LibraryType.UltraLightNode);

        lzEndpointA = address(endpoints[aEid]);
        lzEndpointB = address(endpoints[bEid]);
        vm.label(lzEndpointA, "LayerZero Endpoint A");
        vm.label(lzEndpointB, "LayerZero Endpoint B");

        mockConfigurationManagerA = new MockConfigurationManager();
        mockConfigurationManagerB = new MockConfigurationManager();

        ISummerToken.TokenParams memory tokenParamsA = ISummerToken
            .TokenParams({
                name: "SummerToken A",
                symbol: "SUMMERA",
                lzEndpoint: lzEndpointA,
                // Changed in inheriting test suites
                governor: owner,
                owner: owner,
                rewardsManager: rewardsManagerB,
                configurationManager: address(mockConfigurationManagerA),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
            });

        ISummerToken.TokenParams memory tokenParamsB = ISummerToken
            .TokenParams({
                name: "SummerToken B",
                symbol: "SUMMERB",
                lzEndpoint: lzEndpointB,
                // Changed in inheriting test suites
                owner: owner,
                governor: owner,
                rewardsManager: rewardsManagerB,
                configurationManager: address(mockConfigurationManagerB),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear
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

    function addGovernorToConfigurationManager(
        address _governor,
        MockConfigurationManager _configurationManager
    ) public {
        _configurationManager.setGovernor(_governor);
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
