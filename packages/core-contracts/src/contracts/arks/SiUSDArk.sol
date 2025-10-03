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
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark, denominated in USDC
     * @dev Uses InfiniFi's 1:1 peg mechanism (USDC ↔ iUSD)
     * @dev Decimal conversion: iUSD (18 decimals) → USDC (6 decimals)
     * @dev Rounding: Conservative rounding towards zero
     * @return assets The total balance of USDC-equivalent assets
     */
    function totalAssets() public view override returns (uint256 assets) {
        uint256 siUSDShares = siUSD.balanceOf(address(this));
        if (siUSDShares > 0) {
            // Convert siUSD shares to iUSD amount (18 decimals)
            uint256 iUSDAmount = siUSD.convertToAssets(siUSDShares);
            // Convert iUSD (18 decimals) to USDC equivalent (6 decimals)
            assets = _convertIUSDtoUSDC(iUSDAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts iUSD amount (18 decimals) to USDC equivalent (6 decimals)
     * @dev Uses InfiniFi's 1:1 peg mechanism with decimal adjustment
     * @dev This rounds towards zero, which is the conservative and standard approach
     * @param iUSDAmount The iUSD amount in 18 decimals
     * @return usdcAmount The equivalent USDC amount in 6 decimals
     */
    function _convertIUSDtoUSDC(
        uint256 iUSDAmount
    ) internal pure returns (uint256 usdcAmount) {
        return iUSDAmount / 1e12;
    }

    /**
     * @notice Converts USDC amount (6 decimals) to iUSD equivalent (18 decimals)
     * @dev Uses InfiniFi's 1:1 peg mechanism with decimal adjustment
     * @param usdcAmount The USDC amount in 6 decimals
     * @return iUSDAmount The equivalent iUSD amount in 18 decimals
     */
    function _convertUSDCtoIUSD(
        uint256 usdcAmount
    ) internal pure returns (uint256 iUSDAmount) {
        return usdcAmount * 1e12;
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev Uses InfiniFi's 1:1 peg mechanism
     * @dev Decimal conversion: iUSD (18 decimals) → USDC (6 decimals)
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
            // Convert iUSD (18 decimals) to USDC equivalent (6 decimals)
            withdrawableAssets = _convertIUSDtoUSDC(maxIUSD);
        }
    }

    /**
     * @notice Deposits USDC into InfiniFi via Gateway
     * @dev Uses Gateway.mintAndStake() to convert USDC -> siUSD directly
     * @param amount The amount of USDC to deposit
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Approve Gateway to spend USDC for this specific amount
        config.asset.forceApprove(address(gateway), amount);
        // Use Gateway to mint iUSD and stake to siUSD in one transaction
        gateway.mintAndStake(address(this), amount);
    }

    /**
     * @notice Withdraws USDC from siUSD vault via Gateway
     * @dev Flow: siUSD -> iUSD (unstake) -> USDC (redeem)
     * @param amount The amount of USDC to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // Step 1: Calculate how much iUSD we need (convert USDC decimals to iUSD decimals)
        // This is correct because InfiniFi maintains 1:1 USDC ↔ iUSD peg
        uint256 iUSDNeeded = _convertUSDCtoIUSD(amount);

        // Step 2: Calculate how many siUSD shares we need to unstake to get that much iUSD
        uint256 siUSDSharesToUnstake = siUSD.previewWithdraw(iUSDNeeded);

        // Step 3: Approve Gateway to spend siUSD for this specific amount
        IERC20(address(siUSD)).forceApprove(
            address(gateway),
            siUSDSharesToUnstake
        );
        // Unstake siUSD to receive iUSD via Gateway
        uint256 iUSDReceived = gateway.unstake(
            address(this),
            siUSDSharesToUnstake
        );

        // Step 4: Approve Gateway to spend iUSD for this specific amount
        IERC20(siUSD.asset()).forceApprove(address(gateway), iUSDReceived);

        // Redeem iUSD for USDC - must get exact amount or revert
        gateway.redeem(address(this), iUSDReceived, amount);
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
