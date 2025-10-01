// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IInfiniFiGateway} from "../../interfaces/infinifi/IInfiniFiGateway.sol";

/**
 * @title SiUSDArk
 * @notice Ark contract for managing USDC deposits into InfiniFi's siUSD vault
 * @dev This Ark uses the InfiniFiGateway to handle conversions: USDC → siUSD
 *
 * Flow on deposit (board):
 * 1. Receive USDC from Fleet
 * 2. Use Gateway.mintAndStake() to convert USDC → iUSD → siUSD in one call
 *
 * Flow on withdrawal (disembark):
 * 1. Use Gateway.unstake() to convert siUSD → iUSD
 * 2. Use Gateway.redeem() to convert iUSD → USDC
 * 3. Return USDC to Fleet
 */
contract SiUSDArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The InfiniFi Gateway contract for interacting with the protocol
    IInfiniFiGateway public immutable gateway;

    /// @notice The siUSD (staked iUSD) ERC4626 vault contract
    IERC4626 public immutable siUSD;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidGatewayAddress();
    error InvalidSiUSDAddress();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the SiUSDArk
     * @param _gateway Address of the InfiniFi Gateway contract
     * @param _siUSD Address of the siUSD ERC4626 vault
     * @param _params ArkParams struct containing necessary parameters for Ark initialization
     */
    constructor(
        address _gateway,
        address _siUSD,
        ArkParams memory _params
    ) Ark(_params) {
        if (_gateway == address(0)) {
            revert InvalidGatewayAddress();
        }
        if (_siUSD == address(0)) {
            revert InvalidSiUSDAddress();
        }

        gateway = IInfiniFiGateway(_gateway);
        siUSD = IERC4626(_siUSD);

        // Approve Gateway to spend USDC for mintAndStake operations
        config.asset.forceApprove(_gateway, Constants.MAX_UINT256);

        // Approve Gateway to spend siUSD for unstake operations
        IERC20(_siUSD).forceApprove(_gateway, Constants.MAX_UINT256);

        // Approve Gateway to spend iUSD (siUSD's asset) for redeem operations
        IERC20(siUSD.asset()).forceApprove(_gateway, Constants.MAX_UINT256);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark, denominated in USDC
     * @dev Converts siUSD shares -> iUSD (via ERC4626)
     *      Note: iUSD is approximately 1:1 with USDC (adjusted for decimals)
     *      iUSD has 18 decimals, USDC has 6 decimals
     * @return assets The total balance of USDC-equivalent assets
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 siUSDShares = siUSD.balanceOf(address(this));
        if (siUSDShares > 0) {
            // Convert siUSD shares to iUSD amount (18 decimals)
            uint256 iUSDAmount = siUSD.convertToAssets(siUSDShares);
            // Convert iUSD (18 decimals) to USDC equivalent (6 decimals)
            // iUSD is pegged 1:1 to USD, so we just adjust decimals
            assets = iUSDAmount / 1e12;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Returns the USDC-equivalent value of assets that can be withdrawn
     * @return withdrawableAssets Amount of USDC that can be withdrawn
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 siUSDShares = siUSD.balanceOf(address(this));
        if (siUSDShares > 0) {
            // Get maximum iUSD we can withdraw from siUSD vault (18 decimals)
            uint256 maxIUSD = siUSD.maxWithdraw(address(this));
            // Convert to USDC equivalent (6 decimals)
            withdrawableAssets = maxIUSD / 1e12;
        }
    }

    /**
     * @notice Deposits USDC into InfiniFi via Gateway
     * @dev Uses Gateway.mintAndStake() to convert USDC -> siUSD directly
     * @param amount The amount of USDC to deposit
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Use Gateway to mint iUSD and stake to siUSD in one transaction
        // This returns the amount of iUSD that was minted (and staked)
        gateway.mintAndStake(address(this), amount);
    }

    /**
     * @notice Withdraws USDC from siUSD vault via Gateway
     * @dev Flow: siUSD -> iUSD (unstake) -> USDC (redeem)
     * @param amount The amount of USDC to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // Step 1: Calculate how much iUSD we need (convert USDC decimals to iUSD decimals)
        uint256 iUSDNeeded = amount * 1e12; // USDC (6 dec) -> iUSD (18 dec)

        // Step 2: Calculate how many siUSD shares we need to unstake to get that much iUSD
        uint256 siUSDSharesToUnstake = siUSD.previewWithdraw(iUSDNeeded);

        // Step 3: Unstake siUSD to receive iUSD via Gateway
        uint256 iUSDReceived = gateway.unstake(
            address(this),
            siUSDSharesToUnstake
        );

        // Step 4: Redeem iUSD for USDC via Gateway (with 0 slippage protection for now)
        gateway.redeem(address(this), iUSDReceived, 0);
    }

    /**
     * @notice Validates the board data
     * @dev No additional validation needed for this Ark
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev No additional validation needed for this Ark
     */
    function _validateDisembarkData(bytes calldata) internal override {}

    /**
     * @notice Internal function for harvesting rewards
     * @dev siUSD automatically compounds rewards, no manual harvest needed
     * @return rewardTokens Empty array (no external rewards)
     * @return rewardAmounts Empty array (no external rewards)
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(0);
        rewardAmounts[0] = 0;
    }
}
