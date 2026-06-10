// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC4626
/// @notice Minimal ERC-4626 interface subset used here
interface IERC4626 {
    /// @notice Withdraws `assets` of the underlying token from the vault, burning shares from `owner`
    /// @param assets The amount of underlying assets to withdraw
    /// @param receiver The address that receives the withdrawn assets
    /// @param owner The address whose shares are burned
    /// @return shares The number of shares burned
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);
    /// @notice Returns the maximum amount of underlying assets `owner` can currently withdraw
    /// @param owner The address whose maximum withdrawal is queried
    /// @return The maximum withdrawable amount of underlying assets
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @title IERC20
/// @notice Minimal ERC20 interface subset for token rescue
interface IERC20 {
    /// @notice Transfers `amount` tokens to `to`
    /// @param to The recipient address
    /// @param amount The amount of tokens to transfer
    /// @return True if the transfer succeeded
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title MaxWithdrawExecutor
/// @notice Allows a designated keeper to withdraw the maximum available assets from a hardcoded
///         ERC-4626 vault on behalf of a hardcoded owner, sending underlying tokens directly to them.
/// @dev PREREQUISITE: The OWNER must approve this contract to spend their vault shares before
///      execute() can be called. Call `vault.approve(thisContract, type(uint256).max)` from OWNER.
contract MaxWithdrawExecutor {
    /// @dev Hardcoded vault (ERC-4626) and beneficiary (treasury) addresses
    address public constant VAULT = 0x2433D6AC11193b4695D9ca73530de93c538aD18a;
    /// @notice The hardcoded beneficiary on whose behalf withdrawals are executed
    address public constant OWNER = 0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796;

    /// @notice The address authorized to execute withdrawals and rescue tokens
    address public immutable keeper;

    /// @notice Emitted when a max withdrawal is executed
    /// @param caller The keeper that triggered the withdrawal
    /// @param assetsWithdrawn The amount of underlying assets withdrawn to OWNER
    /// @param sharesBurned The number of vault shares burned
    event Executed(
        address indexed caller,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );
    /// @notice Emitted when ERC20 tokens are rescued from this contract
    /// @param token The rescued token address
    /// @param to The destination address
    /// @param amount The amount transferred
    event RescueToken(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// @notice Thrown when a keeper-only function is called by a non-keeper
    error NotKeeper();
    /// @notice Thrown when there is nothing available to withdraw
    error NothingToWithdraw();
    /// @notice Thrown when an ERC20 transfer returns false
    error TransferFailed();

    constructor(address _keeper) {
        keeper = _keeper;
    }

    /// @notice Restricts a function to the keeper address
    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    /// @notice View the current max withdrawable assets for OWNER from VAULT
    function currentMaxWithdraw() external view returns (uint256) {
        return IERC4626(VAULT).maxWithdraw(OWNER);
    }

    /// @notice Withdraws the full currently-allowed assets to OWNER
    /// @dev Requires OWNER to have previously approved this contract on the vault
    /// @return sharesBurned The number of vault shares burned
    function execute() external onlyKeeper returns (uint256 sharesBurned) {
        IERC4626 vault = IERC4626(VAULT);
        uint256 assets = vault.maxWithdraw(OWNER);
        if (assets == 0) revert NothingToWithdraw();
        // Withdraw underlying directly to OWNER, burning shares owned by OWNER
        sharesBurned = vault.withdraw(assets, OWNER, OWNER);
        emit Executed(msg.sender, assets, sharesBurned);
    }

    /// @notice Rescues ERC20 tokens mistakenly sent to this contract
    /// @param token The ERC20 token address to rescue
    /// @param amount Amount to transfer
    /// @param to Destination address
    function rescueToken(
        address token,
        uint256 amount,
        address to
    ) external onlyKeeper {
        // Allow any nonzero destination; keeper decides where to send
        bool ok = IERC20(token).transfer(to, amount);
        if (!ok) revert TransferFailed();
        emit RescueToken(token, to, amount);
    }
}
