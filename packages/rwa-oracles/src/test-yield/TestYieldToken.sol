// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {YieldPocket} from "./YieldPocket.sol";

/**
 * @title TestYieldToken
 * @author Summer
 * @notice ERC20 share token representing yield positions. Users deposit USDC and receive shares;
 *         they deposit shares and receive USDC on withdrawal. Uses oracle price for conversion.
 * @dev Deposit: user transfers USDC to this contract, owner calls processDeposit to mint shares.
 *      Withdrawal: user transfers shares to this contract, owner calls processWithdraw to burn and send USDC.
 *      Shares use 18 decimals; oracle price uses 8 decimals. Rounds down on both deposit and withdraw.
 */
contract TestYieldToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    /// @notice USDC token address (6 decimals)
    IERC20 public immutable usdc;
    /// @notice Oracle providing price (8 decimals)
    AggregatorV3Interface public immutable oracle;
    /// @notice Pocket holding excess USDC (yield) separate from pending deposits
    YieldPocket public immutable pocket;
    uint8 public constant ORACLE_DECIMALS = 8;
    uint8 public constant USDC_DECIMALS = 6;

    event Deposited(
        address indexed user,
        uint256 usdcAmount,
        uint256 sharesMinted
    );
    event Withdrawn(
        address indexed user,
        uint256 sharesBurned,
        uint256 usdcReturned
    );

    /// @param name ERC20 name
    /// @param symbol ERC20 symbol (typically ticker)
    /// @param _usdc USDC token address
    /// @param _oracle Price oracle (AggregatorV3Interface)
    /// @param _owner Owner (factory) for processDeposit/processWithdraw
    constructor(
        string memory name,
        string memory symbol,
        address _usdc,
        address _oracle,
        address _owner
    ) ERC20(name, symbol) Ownable(_owner) {
        usdc = IERC20(_usdc);
        oracle = AggregatorV3Interface(_oracle);
        // Deploy pocket
        pocket = new YieldPocket(_usdc, address(this));
    }

    /**
     * @notice Returns the pocket contract address.
     * @return Address of the YieldPocket holding excess USDC.
     */
    function getPocket() external view returns (address) {
        return address(pocket);
    }

    /**
     * @notice Process a deposit: mint shares to user for USDC already in this contract.
     * @param user Address to receive minted shares.
     * @param usdcAmount Amount of USDC (6 decimals) to convert. Must be in this contract.
     * @dev USDC is moved to pocket after minting. Rounds down share amount. Reverts if price <= 0.
     */
    function processDeposit(
        address user,
        uint256 usdcAmount
    ) external onlyOwner {
        (, int256 price, , , ) = oracle.latestRoundData();
        require(price > 0, "Invalid price");

        // Logic: shares = (usdc * 1e20) / price
        uint256 shares = (usdcAmount * 1e20) / uint256(price);

        _mint(user, shares);

        // Move USDC to pocket to avoid mixing with future deposits
        // We assume the USDC is already in this contract (transferred by user)
        // If balance is insufficient, this will fail (SafeERC20)
        usdc.safeTransfer(address(pocket), usdcAmount);

        emit Deposited(user, usdcAmount, shares);
    }

    /**
     * @notice Process a withdrawal: burn shares held by this contract and send USDC to user.
     * @param user Address to receive USDC.
     * @param sharesAmount Amount of shares (18 decimals) to burn. Must be held by this contract.
     * @dev Pulls from pocket if main contract has insufficient USDC. Rounds down USDC amount. Reverts if price <= 0.
     */
    function processWithdraw(
        address user,
        uint256 sharesAmount
    ) external onlyOwner {
        (, int256 price, , , ) = oracle.latestRoundData();
        require(price > 0, "Invalid price");

        // Burn shares
        _burn(address(this), sharesAmount);

        // Calculate USDC: (shares * price) / 1e20
        uint256 usdcAmount = (sharesAmount * uint256(price)) / 1e20;

        uint256 contractBalance = usdc.balanceOf(address(this));

        if (contractBalance < usdcAmount) {
            // Pull from pocket
            uint256 needed = usdcAmount - contractBalance;
            pocket.withdraw(address(this), needed);
        }

        usdc.safeTransfer(user, usdcAmount);
        emit Withdrawn(user, sharesAmount, usdcAmount);
    }

    /**
     * @notice Rescue accidentally sent ERC20 tokens.
     * @param token Token address to rescue.
     * @param amount Amount to transfer to owner.
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
