// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SupplyControlSummerToken} from "./SupplyControlSummerToken.sol";
import {ISummerToken} from "../src/interfaces/ISummerToken.sol";

import {EnforcedOptionParam, IOAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IOFT, OFTReceipt, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {SummerTimelockController} from "../src/contracts/SummerTimelockController.sol";

import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {Test, console} from "forge-std/Test.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockSummerGovernor} from "./MockSummerGovernor.sol";
import {SummerVestingWalletFactory} from "../src/contracts/SummerVestingWalletFactory.sol";

contract SummerTokenTestBase is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 public aEid = 1;
    uint32 public bEid = 2;

    SupplyControlSummerToken public aSummerToken;
    SupplyControlSummerToken public bSummerToken;

    SummerVestingWalletFactory public vestingWalletFactoryA;
    SummerVestingWalletFactory public vestingWalletFactoryB;

    SummerTimelockController public timelockA;
    SummerTimelockController public timelockB;

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
        vm.prank(owner);
        aSummerToken.enableTransfers();
        vm.prank(owner);
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

        address fakeDeployerKey = address(0x1234);
        accessManagerA = new ProtocolAccessManager(fakeDeployerKey);
        accessManagerB = new ProtocolAccessManager(fakeDeployerKey);

        address timelockAdmin = address(this);
        timelockA = new SummerTimelockController(
            1 days,
            proposers,
            executors,
            timelockAdmin,
            address(accessManagerA)
        );
        timelockB = new SummerTimelockController(
            1 days,
            proposers,
            executors,
            timelockAdmin,
            address(accessManagerB)
        );

        vm.startPrank(fakeDeployerKey);
        accessManagerA.grantGovernorRole(address(timelockA));
        accessManagerB.grantGovernorRole(address(timelockB));

        accessManagerA.revokeGovernorRole(fakeDeployerKey);
        accessManagerB.revokeGovernorRole(fakeDeployerKey);
        vm.stopPrank();

        vm.label(address(timelockA), "SummerTimelockController A");
        vm.label(address(timelockB), "SummerTimelockController B");

        ISummerToken.TokenParams memory tokenParamsA = ISummerToken
            .TokenParams({
                name: "SummerToken A",
                symbol: "SUMMERA",
                lzEndpoint: lzEndpointA,
                // Changed in inheriting test suites
                owner: owner,
                accessManager: address(accessManagerA),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                transferEnableDate: block.timestamp + 1 days,
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                initialSupply: INITIAL_SUPPLY * 10 ** 18
            });

        ISummerToken.TokenParams memory tokenParamsB = ISummerToken
            .TokenParams({
                name: "SummerToken B",
                symbol: "SUMMERB",
                lzEndpoint: lzEndpointB,
                // Changed in inheriting test suites
                owner: owner,
                accessManager: address(accessManagerB),
                initialDecayFreeWindow: INITIAL_DECAY_FREE_WINDOW,
                initialDecayRate: INITIAL_DECAY_RATE_PER_SECOND,
                initialDecayFunction: VotingDecayLibrary.DecayFunction.Linear,
                transferEnableDate: block.timestamp + 1 days,
                maxSupply: INITIAL_SUPPLY * 10 ** 18,
                initialSupply: 0
            });

        vm.label(owner, "Owner");

        vm.startPrank(owner);
        aSummerToken = new SupplyControlSummerToken(tokenParamsA);
        bSummerToken = new SupplyControlSummerToken(tokenParamsB);
        vm.stopPrank();

        vestingWalletFactoryA = SummerVestingWalletFactory(
            address(aSummerToken.vestingWalletFactory())
        );
        vestingWalletFactoryB = SummerVestingWalletFactory(
            address(bSummerToken.vestingWalletFactory())
        );

        // Config and wire the tokens
        address[] memory tokens = new address[](2);
        tokens[0] = address(aSummerToken);
        tokens[1] = address(bSummerToken);

        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(
            address(aSummerToken.rewardsManager())
        );
        accessManagerA.grantDecayControllerRole(address(aSummerToken));
        accessManagerA.grantGovernorRole(address(this));
        vm.stopPrank();

        vm.startPrank(address(timelockB));
        accessManagerB.grantDecayControllerRole(address(mockGovernor));
        accessManagerB.grantDecayControllerRole(
            address(bSummerToken.rewardsManager())
        );
        accessManagerB.grantDecayControllerRole(address(bSummerToken));
        accessManagerB.grantGovernorRole(address(this));
        vm.stopPrank();

        this.wireOApps(tokens);
    }

    function changeTokensOwnership(
        address _newOwnerA,
        address _newOwnerB
    ) public {
        vm.startPrank(owner);
        aSummerToken.transfer(_newOwnerA, aSummerToken.balanceOf(owner));
        bSummerToken.transfer(_newOwnerB, bSummerToken.balanceOf(owner));
        aSummerToken.transferOwnership(_newOwnerA);
        bSummerToken.transferOwnership(_newOwnerB);
        vm.stopPrank();
    }

    function useNetworkA() public {
        vm.chainId(31337);
    }

    function useNetworkB() public {
        vm.chainId(31338);
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
