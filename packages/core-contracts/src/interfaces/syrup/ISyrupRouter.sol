// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISyrupRouter {
    /**
     *  @dev   Optional Deposit Data for off-chain processing.
     *  @param owner       The receiver of the shares.
     *  @param amount      The amount of assets to deposit.
     *  @param depositData Optional deposit data.
     */
    event DepositData(
        address indexed owner,
        uint256 amount,
        bytes32 depositData
    );

    /**
     *  @dev    Authorizes and deposits assets into the Vault.
     *  @param  bitmap_      The bitmap of the permission.
     *  @param  deadline_    The timestamp after which the `authorize` signature is no longer valid.
     *  @param  auth_v       ECDSA signature v component.
     *  @param  auth_r       ECDSA signature r component.
     *  @param  auth_s       ECDSA signature s component.
     *  @param  amount_      The amount of assets to deposit.
     *  @param  depositData_ Optional deposit data.
     *  @return shares_      The amount of shares minted.
     */
    function authorizeAndDeposit(
        uint256 bitmap_,
        uint256 deadline_,
        uint8 auth_v,
        bytes32 auth_r,
        bytes32 auth_s,
        uint256 amount_,
        bytes32 depositData_
    ) external returns (uint256 shares_);

    /**
     *  @dev    Mints `shares` to sender by depositing `assets` into the Vault.
     *  @param  assets      The amount of assets to deposit.
     *  @param  depositData Optional deposit data.
     *  @return shares      The amount of shares minted.
     */
    function deposit(
        uint256 assets,
        bytes32 depositData
    ) external returns (uint256 shares);

    /**
     *  @dev    Returns the next nonce for the owner's signature.
     *  @param  owner The address to check the nonce for.
     *  @return The next nonce.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     *  @dev    Returns the address of the pool permission manager.
     */
    function poolPermissionManager() external view returns (address);
}
