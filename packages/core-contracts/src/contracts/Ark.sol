// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./ArkAccessControl.sol";
import "../interfaces/IArk.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, ArkAccessControl {
    using SafeERC20 for IERC20;

    IConfigurationManager public configurationManager;
    uint256 public depositCap;
    IERC20 public token;

    constructor(
        ArkParams memory _params
    ) ArkAccessControl(_params.configurationManager) {
        configurationManager = IConfigurationManager(configurationManager);
        token = IERC20(_params.token);
    }

    /* PUBLIC */
    function balance() public view returns (uint256) {}
    function harvest() public {}

    /* EXTERNAL - COMMANDER */
    function board(uint256 amount) external onlyCommander {
        token.safeTransferFrom(msg.sender, address(this), amount);
        _board(amount);

        emit Boarded(msg.sender, address(token), amount);
    }

    function disembark(uint256 amount) external onlyCommander {
        _disembark(amount);
        token.safeTransfer(msg.sender, amount);

        emit Disembarked(msg.sender, address(token), amount);
    }

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {}

    /* INTERNAL */
    function _board(uint256 amount) internal virtual;
    function _disembark(uint256 amount) internal virtual;
}
