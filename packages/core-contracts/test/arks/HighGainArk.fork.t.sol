// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/HighGainArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IFleetCommanderConfigProvider} from "../../src/interfaces/IFleetCommanderConfigProvider.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGainVault} from "../../src/interfaces/highgain/IGainVault.sol";
import {IGainAdapter} from "../../src/interfaces/highgain/IGainAdapter.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {MockGainVault} from "../mocks/MockGainVault.sol";

contract HighGainArkForkTest is Test, ArkTestBase {
    using SafeERC20 for IERC20;

    HighGainArk public ark;
    address public bufferArk;

    address public constant GAIN_ADAPTER_ADDRESS =
        0xB185D98056419029daE7120EcBeFa0DbC12c283A;
    address public constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IGainVault public vault;
    IGainAdapter public adapter;
    IERC20 public weth;

    uint256 forkBlock = 24309649;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(WETH_ADDRESS, "Test Fleet");
        commander = _commander;
        bufferArk = _bufferArk;

        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        weth = IERC20(WETH_ADDRESS);
        adapter = IGainAdapter(GAIN_ADAPTER_ADDRESS);

        // Deploy Mock Vault
        MockGainVault mockVault = new MockGainVault(
            WETH_ADDRESS,
            GAIN_ADAPTER_ADDRESS
        );
        vault = IGainVault(address(mockVault));

        // Whitelist mock vault in adapter (Adapter is real)
        whitelistVaultAndEthIfNeeded();

        ArkParams memory params = ArkParams({
            name: "HighGainArk",
            details: "HighGainArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(weth),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new HighGainArk(address(vault), GAIN_ADAPTER_ADDRESS, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        accessManager.grantCuratorRole(
            address(address(commander)),
            address(curator)
        );
        IFleetCommanderConfigProvider(commander).addArk(address(ark));
        vm.stopPrank();

        vm.startPrank(curator);
        ark.whitelistRouter(ODOS_ROUTER_MAINNET, true);
        vm.stopPrank();

        vm.makePersistent(address(weth));
        vm.makePersistent(address(vault));
        vm.makePersistent(address(adapter));

        vm.label(commander, "Commander");
        vm.label(address(weth), "WETH");
        vm.label(address(vault), "MockGainVault");
        vm.label(address(adapter), "GainAdapter");
        vm.label(address(ark), "Ark");
    }

    function test_Board_HighGain_fork() public {
        uint256 amount = 10 ether;
        deal(address(weth), commander, amount);

        vm.startPrank(commander);
        weth.forceApprove(address(ark), amount);

        ark.board(amount, bytes(""));
        vm.stopPrank();

        uint256 assetsAfter = ark.totalAssets();
        console.log("Assets after board:", assetsAfter);
        assertGt(assetsAfter, 0);
        assertApproxEqAbs(assetsAfter, amount, 0.1 ether);

        // In mock vault, shares are minted. But Ark deposits ETH to Adapter.
        // Adapter calls reserveDeposit on vault.
        // MockVault.reserveDeposit mints shares.
        // Ark checks totalAssets = balance + pending + convertToAssets(sharesInArk).
        // sharesInArk should be > 0.

        uint256 shares = vault.balanceOf(address(ark));
        assertGt(shares, 0);
    }

    function test_RequestWithdrawal_HighGain_fork() public {
        test_Board_HighGain_fork();

        uint256 currentAssets = ark.totalAssets();
        uint256 withdrawAmount = currentAssets / 2;

        vm.prank(keeper);
        ark.requestWithdrawal(withdrawAmount);

        uint256 assetsAfter = ark.totalAssets();
        console.log("Assets after request:", assetsAfter);
        console.log("Withdrawal Queue:", ark.assetsInWithdrawalQueue());

        // assetsInWithdrawalQueue is 0.
        // shares burned in vault.
        // So assetsAfter < currentAssets.
        assertLt(assetsAfter, currentAssets);
    }

    function test_WithdrawUsingSwap_HighGain_fork() public {
        test_Board_HighGain_fork();

        IArkWithWithdrawalRequest.SwapData
            memory swapData = IArkWithWithdrawalRequest.SwapData({
                router: ODOS_ROUTER_MAINNET,
                swapCalldata: hex""
            });
        bytes memory data = abi.encode(swapData);

        vm.prank(keeper);
        try ark.withdrawUsingSwap(1 ether, data) {
            fail();
        } catch (bytes memory) {}
    }

    function whitelistVaultAndEthIfNeeded() internal {
        address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        // Whitelist ETH
        if (!adapter.getIsWhitelistedAsset(ETH)) {
            console.log("Whitelisting ETH in Adapter");
            findAndSetMapping(
                address(adapter),
                ETH,
                true,
                "getIsWhitelistedAsset(address)"
            );
        }

        // Whitelist Mock Vault
        if (!adapter.getIsWhitelistedVault(address(vault))) {
            console.log("Whitelisting Mock Vault in Adapter");
            findAndSetMapping(
                address(adapter),
                address(vault),
                true,
                "getIsWhitelistedVault(address)"
            );

            // Limit slot (273 based on previous check)
            uint256 limitSlot = 273;
            bytes32 slot = keccak256(abi.encode(address(vault), limitSlot));
            vm.store(address(adapter), slot, bytes32(type(uint256).max));
        }
    }

    function findAndSetMapping(
        address target,
        address key,
        bool value,
        string memory getter
    ) internal {
        for (uint256 i = 0; i < 500; i++) {
            bytes32 slot = keccak256(abi.encode(key, i));
            bytes32 current = vm.load(target, slot);
            vm.store(target, slot, bytes32(uint256(value ? 1 : 0)));

            (bool s, bytes memory d) = target.staticcall(
                abi.encodeWithSignature(getter, key)
            );
            if (s && abi.decode(d, (bool)) == value) {
                return;
            }

            vm.store(target, slot, current);
        }
        console.log("Could not find slot for mapping");
    }
}
