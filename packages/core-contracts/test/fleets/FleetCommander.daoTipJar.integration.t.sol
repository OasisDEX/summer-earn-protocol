// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ConfigurationManager} from "@summerfi/config-contracts/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/config-contracts/types/ConfigurationManagerTypes.sol";

import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {TipJar} from "../../src/contracts/TipJar.sol";

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderDao} from "../../src/contracts/FleetCommanderDao.sol";

import {FleetCommanderRewardsManagerFactory} from "../../src/contracts/FleetCommanderRewardsManagerFactory.sol";

import {IFleetCommanderRewardsManager} from "../../src/interfaces/IFleetCommanderRewardsManager.sol";
import {ITipJar} from "../../src/interfaces/ITipJar.sol";

import {FleetCommanderDaoParams, FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract DaoTipJarIntegrationTest is Test {
    using PercentageUtils for uint256;

    address internal governor = makeAddr("governor");
    address internal keeper = makeAddr("keeper");
    address internal guardian = makeAddr("guardian");
    address internal curator = makeAddr("curator");
    address internal treasury = makeAddr("treasury");
    address internal raft = makeAddr("raft");

    address internal userA = makeAddr("userA");
    address internal userB = makeAddr("userB");

    address internal streamRecipient1 = makeAddr("streamRecipient1");
    address internal streamRecipient2 = makeAddr("streamRecipient2");

    ProtocolAccessManager internal accessManager;
    HarborCommand internal harborCommand;
    FleetCommanderRewardsManagerFactory internal rewardsManagerFactory;
    ConfigurationManager internal configurationManager;

    TipJar internal globalTipJar;
    TipJar internal daoTipJar;

    ERC20Mock internal underlying;

    FleetCommander internal nonDaoFleet;
    FleetCommanderDao internal daoFleet;

    function setUp() public {
        underlying = new ERC20Mock();

        accessManager = new ProtocolAccessManager(governor);
        harborCommand = new HarborCommand(address(accessManager));
        rewardsManagerFactory = new FleetCommanderRewardsManagerFactory();
        configurationManager = new ConfigurationManager(address(accessManager));

        // TipJars can be deployed before ConfigurationManager is initialized.
        globalTipJar = new TipJar(
            address(accessManager),
            address(configurationManager)
        );
        daoTipJar = new TipJar(
            address(accessManager),
            address(configurationManager)
        );

        vm.startPrank(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: raft,
                tipJar: address(globalTipJar),
                treasury: treasury,
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(
                    rewardsManagerFactory
                )
            })
        );
        vm.stopPrank();

        // Deploy fleets.
        nonDaoFleet = new FleetCommander(
            FleetCommanderParams({
                name: "NonDaoFleet",
                details: "NonDaoFleet details",
                symbol: "NDF",
                configurationManager: address(configurationManager),
                accessManager: address(accessManager),
                asset: address(underlying),
                initialMinimumBufferBalance: 0,
                initialRebalanceCooldown: 1 minutes,
                depositCap: type(uint256).max,
                initialTipRate: uint256(1).fromIntegerPercentage() // 1%
            })
        );

        daoFleet = new FleetCommanderDao(
            FleetCommanderDaoParams({
                name: "DaoFleet",
                details: "DaoFleet details",
                symbol: "DF",
                configurationManager: address(configurationManager),
                accessManager: address(accessManager),
                asset: address(underlying),
                initialMinimumBufferBalance: 0,
                initialRebalanceCooldown: 1 minutes,
                depositCap: type(uint256).max,
                initialTipRate: uint256(1).fromIntegerPercentage(), // 1%
                tipJar: address(daoTipJar)
            })
        );

        // Enlist both fleets in the same HarborCommand so shakeAll hits both.
        vm.startPrank(governor);
        harborCommand.enlistFleetCommander(address(nonDaoFleet));
        harborCommand.enlistFleetCommander(address(daoFleet));
        vm.stopPrank();

        // Give users assets.
        underlying.mint(userA, 10_000_000 ether);
        underlying.mint(userB, 10_000_000 ether);

        vm.prank(userA);
        underlying.approve(address(nonDaoFleet), type(uint256).max);
        vm.prank(userA);
        underlying.approve(address(daoFleet), type(uint256).max);
    }

    function _addDefaultTipStreams(TipJar jar) internal {
        vm.startPrank(governor);
        jar.addTipStream(
            ITipJar.TipStream({
                recipient: streamRecipient1,
                allocation: uint256(60).fromIntegerPercentage(),
                lockedUntilEpoch: block.timestamp
            })
        );
        jar.addTipStream(
            ITipJar.TipStream({
                recipient: streamRecipient2,
                allocation: uint256(30).fromIntegerPercentage(),
                lockedUntilEpoch: block.timestamp
            })
        );
        vm.stopPrank();
    }

    /// @notice Parses TipJarShaken events from recorded logs for a given tip jar emitter.
    /// @return amountForNonDaoFleet The totalDistributed for nonDaoFleet (0 if not found).
    /// @return amountForDaoFleet The totalDistributed for daoFleet (0 if not found).
    function _parseTipJarShakenAmounts(
        Vm.Log[] memory logs,
        address tipJarEmitter
    )
        internal
        view
        returns (uint256 amountForNonDaoFleet, uint256 amountForDaoFleet)
    {
        bytes32 topic0 = keccak256("TipJarShaken(address,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter != tipJarEmitter ||
                logs[i].topics.length < 2 ||
                logs[i].topics[0] != topic0
            ) {
                continue;
            }
            address fleetCommander = address(
                uint160(uint256(logs[i].topics[1]))
            );
            uint256 amount = abi.decode(logs[i].data, (uint256));
            if (fleetCommander == address(nonDaoFleet)) {
                amountForNonDaoFleet = amount;
            } else if (fleetCommander == address(daoFleet)) {
                amountForDaoFleet = amount;
            }
        }
    }

    function test_DaoAndNonDao_TipJarAddressesDiffer() public view {
        assertEq(
            configurationManager.tipJar(),
            address(globalTipJar),
            "Configuration manager tip jar should be the same as the global tip jar"
        );

        // Non-DAO reads from ConfigurationManager.
        assertEq(
            nonDaoFleet.tipJar(),
            address(globalTipJar),
            "Non-DAO tip jar should be the same as the global tip jar"
        );

        // DAO stores its own tipJar in config and overrides tipJar().
        assertEq(
            daoFleet.getConfig().tipJar,
            address(daoTipJar),
            "DAO tip jar should be the same as the tip jar in the config"
        );
        assertEq(
            daoFleet.tipJar(),
            address(daoTipJar),
            "DAO tip jar should be the same as the tip jar in the config"
        );
        assertNotEq(
            daoFleet.tipJar(),
            nonDaoFleet.tipJar(),
            "DAO tip jar should not be the same as non-DAO tip jar"
        );

        assertTrue(
            nonDaoFleet.tipJar() != daoFleet.tipJar(),
            "Non-DAO tip jar should not be the same as DAO tip jar"
        );
    }

    function test_TipAccrual_MintsSharesToCorrectJar() public {
        // Deposit a large amount to avoid rounding to 0 tips.
        uint256 depositAmount = 1_000_000 ether;

        vm.prank(userA);
        nonDaoFleet.deposit(depositAmount, userA);

        vm.prank(userA);
        daoFleet.deposit(depositAmount, userA);

        // Accrue tips for 1 year.
        vm.warp(block.timestamp + 365 days);

        nonDaoFleet.tip();
        daoFleet.tip();

        // Non-DAO tips go to globalTipJar.
        assertGt(nonDaoFleet.balanceOf(address(globalTipJar)), 0);
        assertEq(nonDaoFleet.balanceOf(address(daoTipJar)), 0);

        // DAO tips go to daoTipJar.
        assertGt(daoFleet.balanceOf(address(daoTipJar)), 0);
        assertEq(daoFleet.balanceOf(address(globalTipJar)), 0);
    }

    function test_ShakeAll_WorksWithDaoAndNonDaoEnlisted() public {
        uint256 depositAmount = 1_000_000 ether;

        vm.prank(userA);
        nonDaoFleet.deposit(depositAmount, userA);
        vm.prank(userA);
        daoFleet.deposit(depositAmount, userA);

        vm.warp(block.timestamp + 365 days);
        nonDaoFleet.tip();
        daoFleet.tip();

        _addDefaultTipStreams(globalTipJar);
        _addDefaultTipStreams(daoTipJar);

        // Shake global jar: should distribute from non-DAO fleet and no-op on DAO fleet.
        uint256 treasuryBeforeGlobal = underlying.balanceOf(treasury);
        uint256 r1BeforeGlobal = underlying.balanceOf(streamRecipient1);
        uint256 r2BeforeGlobal = underlying.balanceOf(streamRecipient2);

        vm.recordLogs();
        globalTipJar.shakeAll();
        (
            uint256 globalNonDaoAmount,
            uint256 globalDaoAmount
        ) = _parseTipJarShakenAmounts(
                vm.getRecordedLogs(),
                address(globalTipJar)
            );
        assertGt(
            globalNonDaoAmount,
            0,
            "globalTipJar should emit TipJarShaken(nonDaoFleet, amount > 0)"
        );
        assertEq(
            globalDaoAmount,
            0,
            "globalTipJar should emit TipJarShaken(daoFleet, 0) on no-op"
        );

        assertEq(nonDaoFleet.balanceOf(address(globalTipJar)), 0);
        assertEq(daoFleet.balanceOf(address(globalTipJar)), 0);
        assertGt(underlying.balanceOf(streamRecipient1), r1BeforeGlobal);
        assertGt(underlying.balanceOf(streamRecipient2), r2BeforeGlobal);
        assertGt(underlying.balanceOf(treasury), treasuryBeforeGlobal);

        // Shake DAO jar: should distribute from DAO fleet and no-op on non-DAO fleet.
        uint256 treasuryBeforeDao = underlying.balanceOf(treasury);
        uint256 r1BeforeDao = underlying.balanceOf(streamRecipient1);
        uint256 r2BeforeDao = underlying.balanceOf(streamRecipient2);

        vm.recordLogs();
        daoTipJar.shakeAll();
        (
            uint256 daoJarNonDaoAmount,
            uint256 daoJarDaoAmount
        ) = _parseTipJarShakenAmounts(vm.getRecordedLogs(), address(daoTipJar));
        assertGt(
            daoJarDaoAmount,
            0,
            "daoTipJar should emit TipJarShaken(daoFleet, amount > 0)"
        );
        assertEq(
            daoJarNonDaoAmount,
            0,
            "daoTipJar should emit TipJarShaken(nonDaoFleet, 0) on no-op"
        );

        assertEq(daoFleet.balanceOf(address(daoTipJar)), 0);
        assertEq(nonDaoFleet.balanceOf(address(daoTipJar)), 0);
        assertGt(underlying.balanceOf(streamRecipient1), r1BeforeDao);
        assertGt(underlying.balanceOf(streamRecipient2), r2BeforeDao);
        assertGt(underlying.balanceOf(treasury), treasuryBeforeDao);
    }

    function test_ShareTransfers_DaoEnabled_NonDaoDisabledUntilGovernorEnables()
        public
    {
        uint256 depositAmount = 1_000 ether;

        vm.prank(userA);
        nonDaoFleet.deposit(depositAmount, userA);
        vm.prank(userA);
        daoFleet.deposit(depositAmount, userA);

        uint256 transferShares = nonDaoFleet.balanceOf(userA) / 10;
        assertGt(transferShares, 0);

        // Non-DAO transfers disabled by default.
        vm.prank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        nonDaoFleet.transfer(userB, transferShares);

        // DAO transfers enabled by default.
        uint256 daoTransferShares = daoFleet.balanceOf(userA) / 10;
        assertGt(daoTransferShares, 0);
        vm.prank(userA);
        assertTrue(daoFleet.transfer(userB, daoTransferShares));

        // Enable non-DAO transfers as governor, then transfer works.
        vm.prank(governor);
        nonDaoFleet.setFleetTokenTransferability();

        vm.prank(userA);
        assertTrue(nonDaoFleet.transfer(userB, transferShares));
    }

    function test_ShareTransfers_NonDao_StakingRewardsManagerException()
        public
    {
        address dummyAddress = makeAddr("dummyAddress");
        // Ensure transfers are still disabled.
        assertEq(nonDaoFleet.transfersEnabled(), false);

        // Get staking rewards manager from config.
        address stakingRewardsManager = nonDaoFleet
            .getConfig()
            .stakingRewardsManager;
        assertTrue(stakingRewardsManager != address(0));

        // Mint shares directly to staking rewards manager by depositing with receiver=stakingRewardsManager.
        uint256 depositAmount = 1_000 ether;
        vm.startPrank(userA);
        nonDaoFleet.deposit(depositAmount, stakingRewardsManager);
        nonDaoFleet.deposit(depositAmount, dummyAddress);
        vm.stopPrank();

        uint256 managerShares = nonDaoFleet.balanceOf(stakingRewardsManager);
        assertGt(managerShares, 0);

        // Transfers should succeed when msg.sender is stakingRewardsManager (exception path).
        vm.prank(stakingRewardsManager);
        assertTrue(nonDaoFleet.transfer(userB, managerShares / 2));
        vm.prank(dummyAddress);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderTransfersDisabled()")
        );
        nonDaoFleet.transfer(userB, managerShares / 2);
    }
}
