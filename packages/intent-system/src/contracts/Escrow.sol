// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolV3} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/IRewardsController.sol";
import {DataTypes} from "@summerfi/earn-protocol-contracts/interfaces/aave-v3/DataTypes.sol";
import {ArkAccessManaged} from "@summerfi/earn-protocol-contracts/contracts/ArkAccessManaged.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";

/**
 * @title Escrow
 * @notice Simple token holding contract for escrowing yield
 * @dev Can be deployed from IntentHandler for each solver
 */
contract Escrow is ReentrancyGuard, IEscrow {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IntentHandler that this escrow works with
    address public immutable intentHandler;
    mapping(bytes32 intentId => uint256 amount) public intentAmounts;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    modifier onlyIntentHandler() {
        if (msg.sender != intentHandler) revert UnauthorizedCaller();
        _;
    }

    constructor(address _intentHandler) {
        intentHandler = _intentHandler;
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(
        address asset,
        uint256 amount,
        bytes32 intentId
    ) external onlyIntentHandler nonReentrant {
        intentAmounts[intentId] = amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(
        address asset,
        address to,
        bytes32 intentId
    ) external onlyIntentHandler nonReentrant returns (uint256 amount) {
        amount = intentAmounts[intentId];
        delete intentAmounts[intentId];
        IERC20(asset).safeTransfer(to, amount);
    }

    error UnauthorizedCaller();
}
