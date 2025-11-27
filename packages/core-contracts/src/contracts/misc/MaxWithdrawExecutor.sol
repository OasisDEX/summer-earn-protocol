// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @notice Minimal ERC-4626 interface subset used here
interface IERC4626 {
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);
    function maxWithdraw(address owner) external view returns (uint256);
}

/// @notice Minimal ERC20 interface subset for token rescue
interface IERC20 {
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
    address public constant OWNER = 0x447BF9d1485ABDc4C1778025DfdfbE8b894C3796;

    /// @dev Contract owner (deployer)
    address public immutable keeper;

    event Executed(
        address indexed caller,
        uint256 assetsWithdrawn,
        uint256 sharesBurned
    );
    event RescueToken(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    error NotKeeper();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(address _keeper) {
        keeper = _keeper;
    }

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
