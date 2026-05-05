// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SuperstateSubscribeArk.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkTestBaseWhitelist} from "./ArkTestBaseWhitelist.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract SuperstateSubscribeArkForkTest is Test, ArkTestBaseWhitelist {
    SuperstateSubscribeArk public ark;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // Superstate USTB constants on Mainnet
    address public constant USTB = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
    address public constant ALLOWLIST = 0x02f1fA8B196d21c7b733EB2700B825611d8A38E5;
    
    // TODO: Add the actual mainnet addresses for the Subscribe, Redeem, and Oracle contracts
    address public constant SUBSCRIBE_TARGET = address(0x1111);
    address public constant REDEEM_TARGET = address(0x2222);
    address public constant ORACLE = address(0x3333);

    uint256 public constant FORK_BLOCK = 21666256;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        initializeCoreContracts();

        ArkParams memory params = ArkParams({
            name: "USTB Superstate Ark",
            details: "USTB Superstate Subscribe Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        // Mock the Oracle and the interfaces if they are just placeholders for now
        // Normally in a fork test we wouldn't mock unless we don't have the addresses.
        vm.mockCall(
            ORACLE,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            ORACLE,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(1, 10 * 1e8, block.timestamp, block.timestamp, 1)
        );

        ark = new SuperstateSubscribeArk(
            SUBSCRIBE_TARGET,
            REDEEM_TARGET,
            ORACLE,
            USTB,
            params
        );

        // Mock the allowlist for the Ark and Commander so transfers succeed
        _mockAllowlist(address(ark), "USTB");
        _mockAllowlist(commander, "USTB");
        _mockAllowlist(SUBSCRIBE_TARGET, "USTB");
        _mockAllowlist(REDEEM_TARGET, "USTB");

        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();
    }

    function _mockAllowlist(address _address, string memory _symbol) internal {
        vm.mockCall(
            ALLOWLIST,
            abi.encodeWithSignature("isAddressAllowedForFund(address,string)", _address, _symbol),
            abi.encode(true)
        );
    }

    function test_Fork_Board() public {
        uint256 amount = 1000 * 10 ** 6; // 1000 USDC
        deal(USDC, commander, amount);

        // Mock the subscribe call since we don't have the real contract address yet
        vm.mockCall(
            SUBSCRIBE_TARGET,
            abi.encodeWithSignature("subscribe(address,uint256,address)", address(ark), amount, USDC),
            abi.encode()
        );
        
        // Mock the token minting that would happen in the real subscribe
        deal(USTB, address(ark), 100 * 10 ** 6);

        vm.startPrank(commander);
        IERC20(USDC).approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        assertEq(ark.totalAssets(), amount);
    }
}
