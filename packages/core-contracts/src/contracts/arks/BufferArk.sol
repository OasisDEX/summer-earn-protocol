// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "../Ark.sol";

/**
 * @title BufferArk
 * @notice Specialized Ark for Fleet Commander Buffer operations. Funds in buffer are not deployed and are not subject to any
 * yield-generating strategies. We keep a ceratin percentage of the total assets in the buffer to ensure that there are always
 * enough assets to quickly disembark ( see {IFleetCommanderConfigProvider-config-minimumBufferBalance}).
 */
contract BufferArk is Ark {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(ArkParams memory _params) Ark(_params) {}

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256) {
        return config.token.balanceOf(address(this));
    }

    /**
     * @notice No-op for board function
     * @dev tokens are transferred using Ark.board()
     */
    function _board(uint256 amount, bytes calldata) internal override {}

    /**
     * @notice No-op for disembark function
     * @dev tokens are transferred using Ark.disembark()
     */
    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override {}

    /**
     * @notice No-op for harvest function
     * @dev BufferArk does not generate any rewards, so this function is not implemented
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}

    /**
     * @notice No-op for validateBoardData function
     * @dev BufferArk does not require any validation for board data
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice No-op for validateDisembarkData function
     * @dev BufferArk does not require any validation for disembark data
     */
    function _validateDisembarkData(bytes calldata data) internal override {}
}
