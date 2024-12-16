// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {ISummerVestingWalletFactory} from "../../src/interfaces/ISummerVestingWalletFactory.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SummerVestingWalletFactoryTest is Test {
    SummerVestingWalletFactory public factory;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;
    address public foundation;
    address public beneficiary;

    event VestingWalletCreated(
        address indexed beneficiary,
        address indexed vestingWallet,
        uint256 timeBasedAmount,
        uint256[] goalAmounts,
        ISummerVestingWallet.VestingType vestingType
    );

    function setUp() public {
        foundation = makeAddr("foundation");
        beneficiary = makeAddr("beneficiary");
        address governor = makeAddr("governor");

        // Deploy access manager with governor address
        vm.startPrank(governor);
        accessManager = new ProtocolAccessManager(governor);
        accessManager.grantFoundationRole(foundation);
        vm.stopPrank();

        // Deploy mock token
        token = new ERC20Mock();

        // Deploy factory
        factory = new SummerVestingWalletFactory(
            address(token),
            address(accessManager)
        );
    }

    function test() public {}

    function test_RevertIf_ZeroTokenAddress() public {
        vm.expectRevert(ISummerVestingWalletFactory.ZeroTokenAddress.selector);
        new SummerVestingWalletFactory(address(0), address(accessManager));
    }

    function test_CreateVestingWallet() public {
        // Setup
        uint256 timeBasedAmount = 100 ether;
        uint256[] memory goalAmounts = new uint256[](2);
        goalAmounts[0] = 50 ether;
        goalAmounts[1] = 50 ether;
        ISummerVestingWallet.VestingType vestingType = ISummerVestingWallet
            .VestingType
            .TeamVesting;

        // Mint tokens to foundation and approve factory
        token.mint(foundation, 200 ether);
        vm.startPrank(foundation);
        token.approve(address(factory), 200 ether);

        // Create vesting wallet
        address vestingWallet = factory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
        vm.stopPrank();

        // Verify mappings
        assertEq(factory.vestingWallets(beneficiary), vestingWallet);
        assertEq(factory.vestingWalletOwners(vestingWallet), beneficiary);

        // Verify token transfer
        assertEq(
            token.balanceOf(vestingWallet),
            timeBasedAmount + goalAmounts[0] + goalAmounts[1]
        );
    }

    function test_RevertIf_VestingWalletAlreadyExists() public {
        // Setup
        uint256 timeBasedAmount = 100 ether;
        uint256[] memory goalAmounts = new uint256[](0);
        ISummerVestingWallet.VestingType vestingType = ISummerVestingWallet
            .VestingType
            .TeamVesting;

        // Create first vesting wallet
        token.mint(foundation, 200 ether);
        vm.startPrank(foundation);
        token.approve(address(factory), 200 ether);
        factory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );

        // Attempt to create second vesting wallet
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactory.VestingWalletAlreadyExists.selector,
                beneficiary
            )
        );
        factory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
        vm.stopPrank();
    }

    function test_RevertIf_InsufficientAllowance() public {
        uint256 timeBasedAmount = 100 ether;
        uint256[] memory goalAmounts = new uint256[](0);
        ISummerVestingWallet.VestingType vestingType = ISummerVestingWallet
            .VestingType
            .TeamVesting;

        token.mint(foundation, 200 ether);
        vm.startPrank(foundation);
        token.approve(address(factory), 50 ether); // Approve less than required

        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactory.InsufficientAllowance.selector,
                100 ether,
                50 ether
            )
        );
        factory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
        vm.stopPrank();
    }

    function test_RevertIf_InsufficientBalance() public {
        uint256 timeBasedAmount = 100 ether;
        uint256[] memory goalAmounts = new uint256[](0);
        ISummerVestingWallet.VestingType vestingType = ISummerVestingWallet
            .VestingType
            .TeamVesting;

        token.mint(foundation, 50 ether); // Mint less than required
        vm.startPrank(foundation);
        token.approve(address(factory), 100 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactory.InsufficientBalance.selector,
                100 ether,
                50 ether
            )
        );
        factory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
        vm.stopPrank();
    }

    function test_RevertIf_IncorrectTransferAmount() public {
        // Deploy factory with incorrect balance token
        MockIncorrectBalanceERC20 incorrectToken = new MockIncorrectBalanceERC20();
        SummerVestingWalletFactory incorrectFactory = new SummerVestingWalletFactory(
                address(incorrectToken),
                address(accessManager)
            );

        uint256 timeBasedAmount = 100 ether;
        uint256[] memory goalAmounts = new uint256[](0);
        ISummerVestingWallet.VestingType vestingType = ISummerVestingWallet
            .VestingType
            .TeamVesting;

        incorrectToken.mint(foundation, 200 ether);
        vm.startPrank(foundation);
        incorrectToken.approve(address(incorrectFactory), 200 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactory.TransferAmountMismatch.selector,
                100 ether,
                50 ether
            )
        );
        incorrectFactory.createVestingWallet(
            beneficiary,
            timeBasedAmount,
            goalAmounts,
            vestingType
        );
        vm.stopPrank();
    }
}

contract MockIncorrectBalanceERC20 is ERC20Mock {
    constructor() ERC20Mock() {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        // Transfer half the amount but return true
        _transfer(from, to, amount / 2);
        return true;
    }
}

contract MockFailingERC20 is ERC20Mock {
    constructor() ERC20Mock() {}

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        return false;
    }
}
