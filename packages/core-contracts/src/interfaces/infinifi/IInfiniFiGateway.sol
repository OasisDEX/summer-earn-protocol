// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IInfiniFiGateway
 * @notice Interface for InfiniFi's Gateway contract
 * @dev The InfiniFiGatewayV2 contract provides user-facing functions to interact with the InfiniFi protocol
 *
 * InfiniFi Architecture:
 * - USDC can be minted to iUSD (InfiniFi's USD stablecoin)
 * - iUSD can be staked to siUSD (yield-bearing staked token)
 * - The Gateway provides convenience functions to handle these flows
 *
 * Deployed at: 0xd04b37f673c42baa46923fe74a830bae721fb41f
 */
interface IInfiniFiGateway {
    /**
     * @notice Mint iUSD from USDC
     * @param _to Address to receive iUSD
     * @param _amount Amount of USDC to deposit
     * @return Amount of iUSD minted (receipt tokens)
     */
    function mint(address _to, uint256 _amount) external returns (uint256);

    /**
     * @notice Mint iUSD from USDC and stake to siUSD in one transaction
     * @param _to Address to receive siUSD shares
     * @param _amount Amount of USDC to deposit
     * @return Amount of iUSD minted (which gets staked)
     */
    function mintAndStake(
        address _to,
        uint256 _amount
    ) external returns (uint256);

    /**
     * @notice Unstake siUSD to receive iUSD
     * @param _to Address to receive iUSD
     * @param _stakedTokens Amount of siUSD to unstake
     * @return Amount of iUSD received (receipt tokens)
     */
    function unstake(
        address _to,
        uint256 _stakedTokens
    ) external returns (uint256);

    /**
     * @notice Redeem iUSD for USDC
     * @param _to Address to receive USDC
     * @param _amount Amount of iUSD to redeem
     * @param _minAssetsOut Minimum amount of USDC to receive (slippage protection)
     * @return Amount of USDC received
     */
    function redeem(
        address _to,
        uint256 _amount,
        uint256 _minAssetsOut
    ) external returns (uint256);
}
