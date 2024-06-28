// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./arks/AaveV3Ark.sol";
import "../interfaces/IArkFactory.sol";
import "../interfaces/IArk.sol";
import "../types/ArkTypes.sol";
import "../types/ArkFactoryTypes.sol";
import "../errors/ArkFactoryErrors.sol";

contract ArkFactory is IArkFactory, ArkAccessControl {
    address public governor;
    address public raft;
    address public aaveV3Pool;

    constructor(ArkFactoryParams memory _params) ArkAccessControl(_params.governor) {
        governor = _params.governor;
        raft = _params.raft;
        aaveV3Pool = _params.aaveV3Pool;
    }

    // NOTE: Do we want specific factory methods or a more generic one (scalable)
    function createAaveV3Ark(address _token) external returns (address) {
        ArkParams memory params = ArkParams({governor: governor, raft: raft, token: _token});
        AaveV3Ark newArk = new AaveV3Ark(aaveV3Pool, params);
        emit ArkCreated(address(newArk), params.raft, params.token, "AaveV3Ark");

        return address(newArk);
    }

    function setRaft(address _newRaft) external onlyGovernor {
        if (_newRaft == address(0)) {
            revert CannotSetRaftToZeroAddress();
        }

        raft = _newRaft;

        emit RaftUpdated(_newRaft);
    }

    function setGovernor(address _newGovernor) external onlyGovernor {
        governor = _newGovernor;

        emit GovernorUpdated(_newGovernor);
    }
}
