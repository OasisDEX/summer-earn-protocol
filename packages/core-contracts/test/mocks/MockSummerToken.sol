// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ISummerToken, SummerVestingWallet} from "@summerfi/earn-gov-contracts/interfaces/ISummerToken.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/src/VotingDecayLibrary.sol";
import {Constants} from "../../src/contracts/libraries/Constants.sol";

contract MockSummerToken is ERC20, ERC20Burnable, ISummerToken {
    uint256 private constant INITIAL_SUPPLY = 1e9;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function createVestingWallet(
        address,
        uint256,
        uint256[] memory,
        SummerVestingWallet.VestingType
    ) external pure {
        revert("Not implemented");
    }

    // Add missing implementations:
    function DOMAIN_SEPARATOR() external pure override returns (bytes32) {
        // Implement or revert
        revert("Not implemented");
    }

    function nonces(address) external pure override returns (uint256) {
        // Implement or revert
        revert("Not implemented");
    }

    function permit(
        address,
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external pure override {
        // Implement or revert
        revert("Not implemented");
    }

    function vestingWallets(address) external pure override returns (address) {
        // Implement or revert
        revert("Not implemented");
    }

    function testSkipper() external pure {
        revert("Not implemented");
    }

    function decayFreeWindow() external pure returns (uint40) {
        revert("Not implemented");
    }

    function decayFunction()
        external
        pure
        returns (VotingDecayLibrary.DecayFunction)
    {
        revert("Not implemented");
    }

    function decayRatePerSecond() external pure returns (uint256) {
        revert("Not implemented");
    }

    function getDecayFactor(address) external pure returns (uint256) {
        return Constants.WAD;
    }

    function getVotingPower(address, uint256) external pure returns (uint256) {
        revert("Not implemented");
    }

    function setDecayRatePerSecond(uint256) external pure {
        revert("Not implemented");
    }

    // Fix the parameter type for setDecayFreeWindow
    function setDecayFreeWindow(uint40) external pure {
        revert("Not implemented");
    }

    function getDecayInfo(
        address
    ) external pure returns (VotingDecayLibrary.DecayInfo memory) {
        revert("Not implemented");
    }

    function setDecayFunction(VotingDecayLibrary.DecayFunction) external pure {
        revert("Not implemented");
    }

    function updateDecayFactor(address) external pure {
        revert("Not implemented");
    }
}
