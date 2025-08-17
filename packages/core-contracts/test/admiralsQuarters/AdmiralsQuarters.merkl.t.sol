// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AdmiralsQuarters} from "../../src/contracts/AdmiralsQuarters.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {IAdmiralsQuartersErrors} from "../../src/errors/IAdmiralsQuartersErrors.sol";
import {IAdmiralsQuarters} from "../../src/interfaces/IAdmiralsQuarters.sol";
import {IFleetCommanderRewardsManager} from "../../src/interfaces/IFleetCommanderRewardsManager.sol";
import {FleetCommanderTestBase} from "../fleets/FleetCommanderTestBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Test, console} from "forge-std/Test.sol";
import {IAdmiralsQuarters} from "../../src/interfaces/IAdmiralsQuarters.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {ISummerRewardsRedeemer} from "@summerfi/rewards-contracts/interfaces/ISummerRewardsRedeemer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IDistributor} from "../../src/interfaces/merkl/IDistributor.sol";

bytes4 constant ENTER_FLEET_SELECTOR = bytes4(
    keccak256("enterFleet(address,uint256,address)")
);
bytes4 constant ENTER_FLEET_WITH_REFERRAL_SELECTOR = bytes4(
    keccak256("enterFleet(address,uint256,address,bytes)")
);

contract AdmiralsQuartersRewardsTest is FleetCommanderTestBase {
    AdmiralsQuarters public admiralsQuarters;
    address public constant ONE_INCH_ROUTER =
        0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable ETH_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // User with actual Merkl claims
    address public constant MERKL_USER =
        0x6D3ef0C74050BA40CeF2D2FFf34B869AA1e2668f;
    address public constant CLAIMED_TOKEN =
        0xBa3335588D9403515223F109EdC4eB7269a9Ab5D;
    address public constant MERKL_DISTRIBUTOR =
        0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    address public user1 = address(0x1111);
    FleetCommander public usdcFleet;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 23024009);

        // Initialize fleet commander
        initializeFleetCommanderWithoutArks(USDC_ADDRESS, 0);
        usdcFleet = fleetCommander;

        vm.startPrank(governor);
        accessManager.grantCommanderRole(
            address(bufferArk),
            address(fleetCommander)
        );

        // Verify fleet commander is enlisted
        require(
            harborCommand.activeFleetCommanders(address(usdcFleet)),
            "Fleet commander not enlisted"
        );

        // Deploy AdmiralsQuarters
        admiralsQuarters = new AdmiralsQuarters(
            ONE_INCH_ROUTER,
            address(configurationManager),
            WETH
        );
        accessManager.grantAdmiralsQuartersRole(address(admiralsQuarters));

        // Setup initial rewards
        address rewardsManager = usdcFleet.getConfig().stakingRewardsManager;
        deal(address(rewardTokens[0]), governor, 1000e6);
        rewardTokens[0].approve(address(rewardsManager), 1000e6);
        IFleetCommanderRewardsManager(rewardsManager).notifyRewardAmount(
            address(rewardTokens[0]),
            1000e6,
            10 days
        );
        vm.stopPrank();

        // Setup user
        deal(USDC_ADDRESS, user1, 1000e6);
        vm.startPrank(user1);
        IERC20(USDC_ADDRESS).approve(
            address(admiralsQuarters),
            type(uint256).max
        );
        vm.stopPrank();
    }

    function test_ClaimMerklRewards() public {
        vm.startPrank(MERKL_USER);

        IDistributor(MERKL_DISTRIBUTOR).toggleOperator(
            MERKL_USER,
            address(admiralsQuarters)
        );

        // Verify operator is whitelisted
        uint256 operatorStatus = IDistributor(MERKL_DISTRIBUTOR).operators(
            MERKL_USER,
            address(admiralsQuarters)
        );
        assertEq(
            operatorStatus,
            1,
            "AdmiralsQuarters should be whitelisted as operator"
        );

        // Now claim rewards on behalf of user
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        bytes32[][] memory proofs = new bytes32[][](1);

        users[0] = MERKL_USER;
        tokens[0] = CLAIMED_TOKEN;
        amounts[0] = 1751610869678070697936381;
        proofs[0] = new bytes32[](15);
        proofs[0][
            0
        ] = 0xf9582354134ac861c3b33105e45edc64969822bf201c7209d75f88d2719826a4;
        proofs[0][
            1
        ] = 0x15bb2008849b503054eba6269c886861c601bf7cabe09b5b2adb892882aac848;
        proofs[0][
            2
        ] = 0x03c4f7e02f04fe723e0830113848315ed38e4e17cfed571e70c06e3572ce020a;
        proofs[0][
            3
        ] = 0x922a8596c2254f6fcd8e5bf62524b7104dc215424229fd9e4f4b6ad5dbb47ed9;
        proofs[0][
            4
        ] = 0x1bbd556c4c305f5cb106843d8ef7df7eece23f15e3e4b744415295c174537fb7;
        proofs[0][
            5
        ] = 0x48d981358d6a331a1de760b18a135a0342bdcd03a4f6febedf19735609028310;
        proofs[0][
            6
        ] = 0x7ac0b54e4fe566a838119d8a0abdb9e4e83862090c753a8d8bf49553e19b762e;
        proofs[0][
            7
        ] = 0x2c24c61d957147f8b10aa2625500d73233d05c51ec32bfade5b70b343e091b1a;
        proofs[0][
            8
        ] = 0xab9f82deded2b9de4485f23adb55d8d44badd65864e1d39e9c57f28ba3d01499;
        proofs[0][
            9
        ] = 0xf1b8fc791b09523ea44dc662f3e5d91ab5cfe16dddc73c09373544ea3e74216b;
        proofs[0][
            10
        ] = 0x02d148383845beac0f222e5381db6c08a969dfbcb43da435ff9022f1454834f4;
        proofs[0][
            11
        ] = 0xac61d5af41f83cc68ba2261401f650f6d8ee5e10cb19c56561a93004cd135432;
        proofs[0][
            12
        ] = 0x8cb662bc41d13992734f28d319698de471d0d081dcf2c121583ad318a0710fe2;
        proofs[0][
            13
        ] = 0x3aafd5ad230734050843183fbf840b24c54e0399e0cf4e534a98483e74e48f98;
        proofs[0][
            14
        ] = 0xac32ab609b689ab6c29cb127ff2e27af534680a87e8344bb1cfe054c0674c0c3;

        // Get initial balance
        uint256 initialBalance = IERC20(CLAIMED_TOKEN).balanceOf(MERKL_USER);

        bytes[] memory claimCalls = new bytes[](1);
        claimCalls[0] = abi.encodeCall(
            admiralsQuarters.claimFromMerklDistributor,
            (users, tokens, amounts, proofs)
        );
        admiralsQuarters.multicall(claimCalls);

        // Verify rewards were claimed
        uint256 finalBalance = IERC20(CLAIMED_TOKEN).balanceOf(MERKL_USER);
        assertGt(
            finalBalance,
            initialBalance,
            "Should have received Merkl rewards"
        );

        vm.stopPrank();
    }
}
