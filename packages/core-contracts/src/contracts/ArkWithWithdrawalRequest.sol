// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {IArkWithWithdrawalRequest} from "../interfaces/IArkWithWithdrawalRequest.sol";
import {ArkConfig, ArkParams} from "../types/ArkTypes.sol";
import {Ark} from "./Ark.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDistributor} from "../interfaces/merkl/IDistributor.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ReentrancyGuardTransient} from "@summerfi/dependencies/openzeppelin-next/ReentrancyGuardTransient.sol";

/**
 * @title Ark
 * @author SummerFi
 * @notice This contract implements the core functionality for the Ark system,
 *         handling asset boarding, disembarking, and harvesting operations.
 * @dev This is an abstract contract that should be inherited by specific Ark implementations.
 *      Inheriting contracts must implement the abstract functions defined here.
 */
abstract contract ArkWithWithdrawalRequest is IArkWithWithdrawalRequest, Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(ArkParams memory _params) Ark(_params) {}

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IArkWithWithdrawalRequest
    function sweep()
        external
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;
        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);

        sweptTokens[0] = address(asset);
        sweptAmounts[0] = asset.balanceOf(address(this));

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );

        if (sweptAmounts[0] > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, sweptAmounts[0]);
            IArk(bufferArk).board(sweptAmounts[0], bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }
}
