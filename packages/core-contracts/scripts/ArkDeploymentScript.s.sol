// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./DeploymentScript.s.sol";

contract ArkDeploymentScript is DeploymentScript {
    uint256 public maxAllocation;

    constructor() {
        maxAllocation = _getMaxAllocation();
    }

    function _getMaxAllocation()
    internal
    view
    returns (uint256)
    {
        uint256 _maxAllocation;
        try vm.envUint("ALLOCATION") returns (uint256 maxAllocation) {
            _maxAllocation = maxAllocation;
        } catch {
            _maxAllocation = 0;
        }

        return _maxAllocation;
    }
}
