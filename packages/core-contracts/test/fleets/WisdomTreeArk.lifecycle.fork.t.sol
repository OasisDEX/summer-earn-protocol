// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import "../../src/contracts/arks/WisdomTreeArk.sol";
import {BufferArk} from "../../src/contracts/arks/BufferArk.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOracle} from "./mocks/MockOracle.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract WisdomTreeArkLifecycleTest is
    Test,
    TestHelpers,
    FleetCommanderTestBase
{
    WisdomTreeArk public usdcWisdomTreeArk;
    BufferArk public usdcBufferArk;
    address public targetWallet;

    MockERC20 public wtToken;
    MockOracle public oracle;

    address[] public usdcArks;

    IERC20 public usdcTokenContract;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 constant FORK_BLOCK = 20376149;

    IFleetCommander public usdcFleetCommander;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);

        targetWallet = makeAddr("targetWallet"); // The external wallet
        setupExternalContracts();
        setupFleetCommanders(0);
        setupArks();
        addArksToFleetCommanders();
    }

    function setupExternalContracts() internal {
        usdcTokenContract = IERC20(USDC_ADDRESS);

        // Setup mocks for WSBTC and Oracle
        wtToken = new MockERC20("WisdomTree Bitcoin", "WTBTC", 18);
        oracle = new MockOracle(8, 60000 * 1e8);
    }

    function setupArks() internal {
        ArkParams memory usdcArkParams = ArkParams({
            name: "USDC WisdomTree Ark",
            details: "USDC WisdomTree Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC_ADDRESS,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Initialize WisdomTreeArk with targetWallet, mock token, and mock oracle
        usdcWisdomTreeArk = new WisdomTreeArk(
            targetWallet,
            address(wtToken),
            address(oracle),
            0,
            usdcArkParams
        );
    }

    function setupFleetCommanders(uint256 initialTipRate) internal {
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, initialTipRate);
        usdcFleetCommander = fleetCommander;
        usdcBufferArk = bufferArk;
    }

    function addArksToFleetCommanders() internal {
        usdcArks = new address[](1);
        usdcArks[0] = address(usdcWisdomTreeArk);

        grantPermissions();

        vm.startPrank(governor);
        usdcFleetCommander.addArk(address(usdcWisdomTreeArk));
        vm.stopPrank();
    }

    function grantPermissions() internal {
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(usdcWisdomTreeArk),
            address(usdcFleetCommander)
        );
        accessManager.grantCommanderRole(
            address(usdcBufferArk),
            address(usdcFleetCommander)
        );
        accessManager.grantKeeperRole(address(usdcFleetCommander), keeper);
        vm.stopPrank();
    }

    function test_DepositRebalanceWithdraw_WisdomTreeArk() public {
        uint256 totalDeposit = 1000 * 10 ** 6; // 1000 USDC
        address user = address(0x1);
        deal(USDC_ADDRESS, user, totalDeposit);

        // 1. Set Fleet Parameters (Deposit Cap and Min Buffer)
        setFleetParameters(usdcFleetCommander, type(uint256).max, 0);

        // 2. User Deposits
        depositForUser(
            usdcFleetCommander,
            usdcTokenContract,
            user,
            totalDeposit
        );

        // 2. Rebalance to WisdomTreeArk
        rebalanceFleetToArk(
            usdcFleetCommander,
            address(usdcWisdomTreeArk),
            totalDeposit
        );

        // Verify funds moved to target wallet
        assertEq(
            usdcTokenContract.balanceOf(targetWallet),
            totalDeposit,
            "Target wallet should receive funds"
        );
        assertEq(
            usdcWisdomTreeArk.pendingDepositAssets(),
            totalDeposit,
            "Ark should track pending assets"
        );
        assertEq(
            usdcWisdomTreeArk.totalAssets(),
            totalDeposit,
            "Ark should track deposited assets via cache"
        );

        // 3. Keeper clears deposit
        // WisdomTree issues shares off-chain
        uint256 expectedShares = (1000 * 1e18) / 60000; // rough mock equivalent
        wtToken.mint(address(usdcWisdomTreeArk), expectedShares);

        vm.prank(keeper);
        usdcWisdomTreeArk.clearPendingDeposit();

        // 4. User Withdraw Request -> Fails. Users cannot directly withdraw from WisdomTreeArk
        // It relies on FleetCommander rebalance logic or off-chain requests.
        // Let's test the off chain withdrawal manual request via keeper instead.

        vm.prank(keeper);
        usdcWisdomTreeArk.requestWithdrawal(totalDeposit);

        // 5. Sweep
        deal(USDC_ADDRESS, address(usdcWisdomTreeArk), totalDeposit);
        vm.prank(keeper);
        usdcWisdomTreeArk.sweep();

        assertEq(
            usdcWisdomTreeArk.totalAssets(),
            0,
            "Ark should have 0 assets tracked after sweep"
        );
    }

    // Helper functions (copied/adapted from FleetCommander.lifecycle.fork.t.sol)

    function setFleetParameters(
        IFleetCommander fleet,
        uint256 depositCap,
        uint256 minBufferBalance
    ) internal {
        FleetCommanderStorageWriter storageWriter = new FleetCommanderStorageWriter(
                address(fleet)
            );
        storageWriter.setDepositCap(depositCap);
        storageWriter.setminimumBufferBalance(minBufferBalance);
    }

    function depositForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        token.approve(address(fleet), amount);
        fleet.deposit(amount, user);
        vm.stopPrank();
    }

    function withdrawForUser(
        IFleetCommander fleet,
        IERC20 token,
        address user,
        uint256 amount
    ) internal {
        vm.startPrank(user);
        fleet.withdraw(amount, user, user);
        vm.stopPrank();
    }

    function rebalanceFleetToArk(
        IFleetCommander fleet,
        address ark,
        uint256 amount
    ) internal {
        FleetConfig memory config = fleet.getConfig();
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark,
            amount: amount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        vm.warp(block.timestamp + 1 days);
        vm.prank(keeper);
        fleet.rebalance(rebalanceData);
    }
}
