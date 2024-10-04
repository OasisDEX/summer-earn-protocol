// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "../Ark.sol";

/**
 * @title BufferArk
 * @notice Specialized Ark for Fleet Commander Buffer operations. Funds in buffer are not deployed and are not subject
 * to any
 * yield-generating strategies. We keep a ceratin percentage of the total assets in the buffer to ensure that there are
 * always
 * enough assets to quickly disembark ( see {IFleetCommanderConfigProvider-config-minimumBufferBalance}).
 */
contract BufferArk is Ark {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        ArkParams memory _params,
        address commanderAddress
    ) Ark(_params) {
        config.commander = commanderAddress;
    }

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
     * @dev This function is intentionally left empty because the BufferArk doesn't need to perform any
     * additional actions when boarding tokens. The actual token transfer is handled by the Ark.board() function,
     * and the BufferArk simply holds these tokens without deploying them to any strategy.
     * @param amount The amount of tokens being boarded (unused in this implementation)
     * @param data Additional data for boarding (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata data) internal override {}

    /**
     * @notice No-op for disembark function
     * @dev This function is intentionally left empty because the BufferArk doesn't need to perform any
     * additional actions when disembarking tokens. The actual token transfer is handled by the Ark.disembark() function,
     * and the BufferArk simply releases these tokens without any complex withdrawal process.
     * @param amount The amount of tokens being disembarked (unused in this implementation)
     * @param data Additional data for disembarking (unused in this implementation)
     */
    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override {}

    /**
     * @notice No-op for harvest function
     * @dev This function is intentionally left empty and returns empty arrays because the BufferArk
     * does not generate any rewards. It's a simple holding contract for tokens, not an investment strategy.
     * @param data Additional data for harvesting (unused in this implementation)
     * @return rewardTokens An empty array of reward token addresses
     * @return rewardAmounts An empty array of reward amounts
     */
    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {}

    /**
     * @notice No-op for validateBoardData function
     * @dev This function is intentionally left empty because the BufferArk doesn't require any
     * specific validation for boarding data. It accepts any data without validation.
     * @param data The boarding data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice No-op for validateDisembarkData function
     * @dev This function is intentionally left empty because the BufferArk doesn't require any
     * specific validation for disembarking data. It accepts any data without validation.
     * @param data The disembarking data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata data) internal override {}
}
