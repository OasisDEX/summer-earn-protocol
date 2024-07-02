// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./ArkAccessControl.sol";
import "../interfaces/IArk.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ArkEvents.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessControl, ArkEvents {
    address public raft;
    uint256 public depositCap;
    IERC20 public token;

    constructor(ArkParams memory _params) ArkAccessControl(_params.governor, address(this)) {
        raft = _params.raft;
        token = IERC20(_params.token);
    }

    /* PUBLIC */
    function balance() public view returns (uint256) {}
    function harvest() public {}

    /* EXTERNAL - COMMANDER */
    function board(uint256 amount) external virtual;
    function disembark(uint256 amount) external virtual;

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {}
    function setRaft(address newRaft) external onlyGovernor {}
}
