// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";

contract SupplyControlSummerToken is SummerToken {
    constructor(
        ISummerToken.ConstructorParams memory params
    ) SummerToken(params) {}

    /// @notice Burns all existing supply and mints a new custom amount
    /// @dev Only for testing purposes
    function setTotalSupply(uint256 newSupply) external {
        // Burn all existing supply
        _burn(address(this), totalSupply());
        // Mint new supply
        _mint(address(this), newSupply);
    }

    /// @notice External mint function for testing
    /// @dev Only for testing purposes
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function exposed_getPeerOrRevert(
        uint32 _eid
    ) external view returns (bytes32) {
        return _getPeerOrRevert(_eid);
    }

    function testSkipper() external pure {
        revert("Not implemented");
    }

    /// @notice Exposes the decay function type for testing
    /// @return The current decay function type (Linear or Exponential)
    function getDecayFunction()
        external
        view
        returns (VotingDecayLibrary.DecayFunction)
    {
        return decayState.decayFunction;
    }

    /// @notice Exposes the decay rate per second for testing
    function getDecayRatePerSecond() external view returns (uint256) {
        return decayState.decayRatePerSecond;
    }
}
