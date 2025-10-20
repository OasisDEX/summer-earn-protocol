// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28 >=0.8.19 ^0.8.20;

// node_modules/@summerfi/access-contracts/src/interfaces/IAccessControlErrors.sol

/**
 * @title IAccessControlErrors
 * @dev This file contains custom error definitions for access control in the system.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IAccessControlErrors {
    /**
     * @notice Thrown when a caller does not have the required role.
     */
    error CallerIsNotContractSpecificRole(address caller, bytes32 role);

    /**
     * @notice Thrown when a caller is not the curator.
     */
    error CallerIsNotCurator(address caller);

    /**
     * @notice Thrown when a caller is not the governor.
     */
    error CallerIsNotGovernor(address caller);

    /**
     * @notice Thrown when a caller is not a keeper.
     */
    error CallerIsNotKeeper(address caller);

    /**
     * @notice Thrown when a caller is not a super keeper.
     */
    error CallerIsNotSuperKeeper(address caller);

    /**
     * @notice Thrown when a caller is not the commander.
     */
    error CallerIsNotCommander(address caller);

    /**
     * @notice Thrown when a caller is neither the Raft nor the commander.
     */
    error CallerIsNotRaftOrCommander(address caller);

    /**
     * @notice Thrown when a caller is not the Raft.
     */
    error CallerIsNotRaft(address caller);

    /**
     * @notice Thrown when a caller is not an admin.
     */
    error CallerIsNotAdmin(address caller);

    /**
     * @notice Thrown when a caller is not the guardian.
     */
    error CallerIsNotGuardian(address caller);

    /**
     * @notice Thrown when a caller is not the guardian or governor.
     */
    error CallerIsNotGuardianOrGovernor(address caller);

    /**
     * @notice Thrown when a caller is not the decay controller.
     */
    error CallerIsNotDecayController(address caller);

    /**
     * @notice Thrown when a caller is not authorized to board.
     */
    error CallerIsNotAuthorizedToBoard(address caller);

    /**
     * @notice Thrown when direct grant is disabled.
     */
    error DirectGrantIsDisabled(address caller);

    /**
     * @notice Thrown when direct revoke is disabled.
     */
    error DirectRevokeIsDisabled(address caller);

    /**
     * @notice Thrown when an invalid access manager address is provided.
     */
    error InvalidAccessManagerAddress(address invalidAddress);

    /**
     * @notice Error thrown when a caller is not the Foundation
     * @param caller The address that attempted the operation
     */
    error CallerIsNotFoundation(address caller);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

/**
 * @dev External interface of AccessControl declared to support ERC-165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call. This account bears the admin role (for the granted role).
     * Expected in cases where the role was granted using the internal {AccessControl-_grantRole}.
     */
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed,
        uint256 tokenId
    );

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/Errors.sol

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/Panic.sol

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state
library Panic {
    /// @dev generic / unspecified error
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

/**
 * @dev Wrappers over Solidity's uintXX/intXX/bool casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }

    /**
     * @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/Common.sol

// Common.sol
//
// Common mathematical functions used in both SD59x18 and UD60x18. Note that these global functions do not
// always operate with SD59x18 and UD60x18 numbers.

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the resultant value in {mulDiv} overflows uint256.
error PRBMath_MulDiv_Overflow(uint256 x, uint256 y, uint256 denominator);

/// @notice Thrown when the resultant value in {mulDiv18} overflows uint256.
error PRBMath_MulDiv18_Overflow(uint256 x, uint256 y);

/// @notice Thrown when one of the inputs passed to {mulDivSigned} is `type(int256).min`.
error PRBMath_MulDivSigned_InputTooSmall();

/// @notice Thrown when the resultant value in {mulDivSigned} overflows int256.
error PRBMath_MulDivSigned_Overflow(int256 x, int256 y);

/*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
//////////////////////////////////////////////////////////////////////////*/

/// @dev The maximum value a uint128 number can have.
uint128 constant MAX_UINT128 = type(uint128).max;

/// @dev The maximum value a uint40 number can have.
uint40 constant MAX_UINT40 = type(uint40).max;

/// @dev The maximum value a uint64 number can have.
uint64 constant MAX_UINT64 = type(uint64).max;

/// @dev The unit number, which the decimal precision of the fixed-point types.
uint256 constant UNIT_0 = 1e18;

/// @dev The unit number inverted mod 2^256.
uint256 constant UNIT_INVERSE = 78156646155174841979727994598816262306175212592076161876661_508869554232690281;

/// @dev The the largest power of two that divides the decimal value of `UNIT`. The logarithm of this value is the least significant
/// bit in the binary representation of `UNIT`.
uint256 constant UNIT_LPOTD = 262144;

/*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the binary exponent of x using the binary fraction method.
/// @dev Has to use 192.64-bit fixed-point numbers. See https://ethereum.stackexchange.com/a/96594/24693.
/// @param x The exponent as an unsigned 192.64-bit fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function exp2_0(uint256 x) pure returns (uint256 result) {
    unchecked {
        // Start from 0.5 in the 192.64-bit fixed-point format.
        result = 0x800000000000000000000000000000000000000000000000;

        // The following logic multiplies the result by $\sqrt{2^{-i}}$ when the bit at position i is 1. Key points:
        //
        // 1. Intermediate results will not overflow, as the starting point is 2^191 and all magic factors are under 2^65.
        // 2. The rationale for organizing the if statements into groups of 8 is gas savings. If the result of performing
        // a bitwise AND operation between x and any value in the array [0x80; 0x40; 0x20; 0x10; 0x08; 0x04; 0x02; 0x01] is 1,
        // we know that `x & 0xFF` is also 1.
        if (x & 0xFF00000000000000 > 0) {
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
        }

        if (x & 0xFF000000000000 > 0) {
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
        }

        if (x & 0xFF0000000000 > 0) {
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
        }

        if (x & 0xFF00000000 > 0) {
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
        }

        if (x & 0xFF000000 > 0) {
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
        }

        if (x & 0xFF0000 > 0) {
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
        }

        if (x & 0xFF00 > 0) {
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
        }

        if (x & 0xFF > 0) {
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
        }

        // In the code snippet below, two operations are executed simultaneously:
        //
        // 1. The result is multiplied by $(2^n + 1)$, where $2^n$ represents the integer part, and the additional 1
        // accounts for the initial guess of 0.5. This is achieved by subtracting from 191 instead of 192.
        // 2. The result is then converted to an unsigned 60.18-decimal fixed-point format.
        //
        // The underlying logic is based on the relationship $2^{191-ip} = 2^{ip} / 2^{191}$, where $ip$ denotes the,
        // integer part, $2^n$.
        result *= UNIT_0;
        result >>= (191 - (x >> 64));
    }
}

/// @notice Finds the zero-based index of the first 1 in the binary representation of x.
///
/// @dev See the note on "msb" in this Wikipedia article: https://en.wikipedia.org/wiki/Find_first_set
///
/// Each step in this implementation is equivalent to this high-level code:
///
/// ```solidity
/// if (x >= 2 ** 128) {
///     x >>= 128;
///     result += 128;
/// }
/// ```
///
/// Where 128 is replaced with each respective power of two factor. See the full high-level implementation here:
/// https://gist.github.com/PaulRBerg/f932f8693f2733e30c4d479e8e980948
///
/// The Yul instructions used below are:
///
/// - "gt" is "greater than"
/// - "or" is the OR bitwise operator
/// - "shl" is "shift left"
/// - "shr" is "shift right"
///
/// @param x The uint256 number for which to find the index of the most significant bit.
/// @return result The index of the most significant bit as a uint256.
/// @custom:smtchecker abstract-function-nondet
function msb(uint256 x) pure returns (uint256 result) {
    // 2^128
    assembly ("memory-safe") {
        let factor := shl(7, gt(x, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^64
    assembly ("memory-safe") {
        let factor := shl(6, gt(x, 0xFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^32
    assembly ("memory-safe") {
        let factor := shl(5, gt(x, 0xFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^16
    assembly ("memory-safe") {
        let factor := shl(4, gt(x, 0xFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^8
    assembly ("memory-safe") {
        let factor := shl(3, gt(x, 0xFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^4
    assembly ("memory-safe") {
        let factor := shl(2, gt(x, 0xF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^2
    assembly ("memory-safe") {
        let factor := shl(1, gt(x, 0x3))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^1
    // No need to shift x any more.
    assembly ("memory-safe") {
        let factor := gt(x, 0x1)
        result := or(result, factor)
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev Credits to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - The denominator must not be zero.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as a uint256.
/// @param y The multiplier as a uint256.
/// @param denominator The divisor as a uint256.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function mulDiv(
    uint256 x,
    uint256 y,
    uint256 denominator
) pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
    // use the Chinese Remainder Theorem to reconstruct the 512-bit result. The result is stored in two 256
    // variables such that product = prod1 * 2^256 + prod0.
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division.
    if (prod1 == 0) {
        unchecked {
            return prod0 / denominator;
        }
    }

    // Make sure the result is less than 2^256. Also prevents denominator == 0.
    if (prod1 >= denominator) {
        revert PRBMath_MulDiv_Overflow(x, y, denominator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // 512 by 256 division
    ////////////////////////////////////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0].
    uint256 remainder;
    assembly ("memory-safe") {
        // Compute remainder using the mulmod Yul instruction.
        remainder := mulmod(x, y, denominator)

        // Subtract 256 bit number from 512-bit number.
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
    }

    unchecked {
        // Calculate the largest power of two divisor of the denominator using the unary operator ~. This operation cannot overflow
        // because the denominator cannot be zero at this point in the function execution. The result is always >= 1.
        // For more detail, see https://cs.stackexchange.com/q/138556/92363.
        uint256 lpotdod = denominator & (~denominator + 1);
        uint256 flippedLpotdod;

        assembly ("memory-safe") {
            // Factor powers of two out of denominator.
            denominator := div(denominator, lpotdod)

            // Divide [prod1 prod0] by lpotdod.
            prod0 := div(prod0, lpotdod)

            // Get the flipped value `2^256 / lpotdod`. If the `lpotdod` is zero, the flipped value is one.
            // `sub(0, lpotdod)` produces the two's complement version of `lpotdod`, which is equivalent to flipping all the bits.
            // However, `div` interprets this value as an unsigned value: https://ethereum.stackexchange.com/q/147168/24693
            flippedLpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
        }

        // Shift in bits from prod1 into prod0.
        prod0 |= prod1 * flippedLpotdod;

        // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
        // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
        // four bits. That is, denominator * inv = 1 mod 2^4.
        uint256 inverse = (3 * denominator) ^ 2;

        // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
        // in modular arithmetic, doubling the correct bits in each step.
        inverse *= 2 - denominator * inverse; // inverse mod 2^8
        inverse *= 2 - denominator * inverse; // inverse mod 2^16
        inverse *= 2 - denominator * inverse; // inverse mod 2^32
        inverse *= 2 - denominator * inverse; // inverse mod 2^64
        inverse *= 2 - denominator * inverse; // inverse mod 2^128
        inverse *= 2 - denominator * inverse; // inverse mod 2^256

        // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
        // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
        // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inverse;
    }
}

/// @notice Calculates x*y÷1e18 with 512-bit precision.
///
/// @dev A variant of {mulDiv} with constant folding, i.e. in which the denominator is hard coded to 1e18.
///
/// Notes:
/// - The body is purposely left uncommented; to understand how this works, see the documentation in {mulDiv}.
/// - The result is rounded toward zero.
/// - We take as an axiom that the result cannot be `MAX_UINT256` when x and y solve the following system of equations:
///
/// $$
/// \begin{cases}
///     x * y = MAX\_UINT256 * UNIT \\
///     (x * y) \% UNIT \geq \frac{UNIT}{2}
/// \end{cases}
/// $$
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
/// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function mulDiv18(uint256 x, uint256 y) pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 == 0) {
        unchecked {
            return prod0 / UNIT_0;
        }
    }

    if (prod1 >= UNIT_0) {
        revert PRBMath_MulDiv18_Overflow(x, y);
    }

    uint256 remainder;
    assembly ("memory-safe") {
        remainder := mulmod(x, y, UNIT_0)
        result := mul(
            or(
                div(sub(prod0, remainder), UNIT_LPOTD),
                mul(
                    sub(prod1, gt(remainder, prod0)),
                    add(div(sub(0, UNIT_LPOTD), UNIT_LPOTD), 1)
                )
            ),
            UNIT_INVERSE
        )
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev This is an extension of {mulDiv} for signed numbers, which works by computing the signs and the absolute values separately.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - None of the inputs can be `type(int256).min`.
/// - The result must fit in int256.
///
/// @param x The multiplicand as an int256.
/// @param y The multiplier as an int256.
/// @param denominator The divisor as an int256.
/// @return result The result as an int256.
/// @custom:smtchecker abstract-function-nondet
function mulDivSigned(
    int256 x,
    int256 y,
    int256 denominator
) pure returns (int256 result) {
    if (
        x == type(int256).min ||
        y == type(int256).min ||
        denominator == type(int256).min
    ) {
        revert PRBMath_MulDivSigned_InputTooSmall();
    }

    // Get hold of the absolute values of x, y and the denominator.
    uint256 xAbs;
    uint256 yAbs;
    uint256 dAbs;
    unchecked {
        xAbs = x < 0 ? uint256(-x) : uint256(x);
        yAbs = y < 0 ? uint256(-y) : uint256(y);
        dAbs = denominator < 0 ? uint256(-denominator) : uint256(denominator);
    }

    // Compute the absolute value of x*y÷denominator. The result must fit in int256.
    uint256 resultAbs = mulDiv(xAbs, yAbs, dAbs);
    if (resultAbs > uint256(type(int256).max)) {
        revert PRBMath_MulDivSigned_Overflow(x, y);
    }

    // Get the signs of x, y and the denominator.
    uint256 sx;
    uint256 sy;
    uint256 sd;
    assembly ("memory-safe") {
        // "sgt" is the "signed greater than" assembly instruction and "sub(0,1)" is -1 in two's complement.
        sx := sgt(x, sub(0, 1))
        sy := sgt(y, sub(0, 1))
        sd := sgt(denominator, sub(0, 1))
    }

    // XOR over sx, sy and sd. What this does is to check whether there are 1 or 3 negative signs in the inputs.
    // If there are, the result should be negative. Otherwise, it should be positive.
    unchecked {
        result = sx ^ sy ^ sd == 0 ? -int256(resultAbs) : int256(resultAbs);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - If x is not a perfect square, the result is rounded down.
/// - Credits to OpenZeppelin for the explanations in comments below.
///
/// @param x The uint256 number for which to calculate the square root.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function sqrt_0(uint256 x) pure returns (uint256 result) {
    if (x == 0) {
        return 0;
    }

    // For our first guess, we calculate the biggest power of 2 which is smaller than the square root of x.
    //
    // We know that the "msb" (most significant bit) of x is a power of 2 such that we have:
    //
    // $$
    // msb(x) <= x <= 2*msb(x)$
    // $$
    //
    // We write $msb(x)$ as $2^k$, and we get:
    //
    // $$
    // k = log_2(x)
    // $$
    //
    // Thus, we can write the initial inequality as:
    //
    // $$
    // 2^{log_2(x)} <= x <= 2*2^{log_2(x)+1} \\
    // sqrt(2^k) <= sqrt(x) < sqrt(2^{k+1}) \\
    // 2^{k/2} <= sqrt(x) < 2^{(k+1)/2} <= 2^{(k/2)+1}
    // $$
    //
    // Consequently, $2^{log_2(x) /2} is a good first approximation of sqrt(x) with at least one correct bit.
    uint256 xAux = uint256(x);
    result = 1;
    if (xAux >= 2 ** 128) {
        xAux >>= 128;
        result <<= 64;
    }
    if (xAux >= 2 ** 64) {
        xAux >>= 64;
        result <<= 32;
    }
    if (xAux >= 2 ** 32) {
        xAux >>= 32;
        result <<= 16;
    }
    if (xAux >= 2 ** 16) {
        xAux >>= 16;
        result <<= 8;
    }
    if (xAux >= 2 ** 8) {
        xAux >>= 8;
        result <<= 4;
    }
    if (xAux >= 2 ** 4) {
        xAux >>= 4;
        result <<= 2;
    }
    if (xAux >= 2 ** 2) {
        result <<= 1;
    }

    // At this point, `result` is an estimation with at least one bit of precision. We know the true value has at
    // most 128 bits, since it is the square root of a uint256. Newton's method converges quadratically (precision
    // doubles at every iteration). We thus need at most 7 iteration to turn our partial result with one bit of
    // precision into the expected uint128 result.
    unchecked {
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;

        // If x is not a perfect square, round the result toward zero.
        uint256 roundedResult = x / result;
        if (result >= roundedResult) {
            result = roundedResult;
        }
    }
}

// node_modules/@summerfi/dutch-auction/src/DutchAuctionErrors.sol

/**
 * @title Dutch Auction Errors
 * @notice This contract defines custom errors for the Dutch Auction system
 */
contract DutchAuctionErrors {
    /**
     * @notice Thrown when the auction duration is set to zero
     * @dev The auction duration must be greater than zero
     */
    error InvalidDuration();

    /**
     * @notice Thrown when the start price is not greater than the end price
     * @dev The start price must be strictly greater than the end price
     */
    error InvalidPrices();

    /**
     * @notice Thrown when the total number of tokens for auction is zero
     * @dev The total token amount must be greater than zero
     */
    error InvalidTokenAmount();

    /**
     * @notice Thrown when the kicker reward percentage is greater than 100%
     * @dev The kicker reward percentage must be between 0 and 100 inclusive
     */
    error InvalidKickerRewardPercentage();

    /**
     * @notice Thrown when trying to buy tokens outside the active auction period
     * @dev This can occur if trying to buy after the auction has ended
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionNotActive(uint256 auctionId);

    /**
     * @notice Thrown when trying to buy more tokens than are available in the auction
     * @dev The requested purchase amount must not exceed the remaining tokens
     */
    error InsufficientTokensAvailable();

    /**
     * @notice Thrown when trying to finalize an auction before its end time
     * @dev The auction can only be finalized after its scheduled end time
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionNotEnded(uint256 auctionId);

    /**
     * @notice Thrown when trying to interact with an auction that has already been finalized
     * @dev Once an auction is finalized, no further interactions should be possible
     * @dev auction is finalized when either the end time is reached or all tokens are sold
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionAlreadyFinalized(uint256 auctionId);

    /**
     * @notice Thrown when the auction token is invalid
     */
    error InvalidAuctionToken();

    /**
     * @notice Thrown when the payment token is invalid
     */
    error InvalidPaymentToken();

    /**
     * @notice Thrown when the auction has not been found
     */
    error AuctionNotFound();
}

// node_modules/@summerfi/dutch-auction/src/DutchAuctionEvents.sol

contract DutchAuctionEvents {
    /**
     * @dev Emitted when a new auction is created
     * @param auctionId The unique identifier of the created auction
     * @param auctionKicker The address of the account that initiated the auction
     * @param totalTokens The total number of tokens being auctioned
     * @param kickerRewardAmount The number of tokens reserved as a reward for the auction kicker
     */
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed auctionKicker,
        uint256 totalTokens,
        uint256 kickerRewardAmount
    );

    /**
     * @dev Emitted when tokens are purchased in an auction
     * @param auctionId The unique identifier of the auction
     * @param buyer The address of the account that purchased the tokens
     * @param amount The number of tokens purchased
     * @param price The price per token at the time of purchase
     */
    event TokensPurchased(
        uint256 indexed auctionId,
        address indexed buyer,
        uint256 amount,
        uint256 price
    );

    /**
     * @dev Emitted when an auction is finalized
     * @param auctionId The unique identifier of the finalized auction
     * @param soldTokens The total number of tokens sold in the auction
     * @param unsoldTokens The number of tokens that remained unsold
     */
    event AuctionFinalized(
        uint256 indexed auctionId,
        uint256 soldTokens,
        uint256 unsoldTokens
    );

    /**
     *
     * @param auctionId The unique identifier of the auction
     * @param kicker The address of the account that initiated the auction
     * @param amount The number of tokens claimed as a reward
     */
    event KickerRewardClaimed(
        uint256 indexed auctionId,
        address indexed kicker,
        uint256 amount
    );
}

// node_modules/@summerfi/percentage-solidity/contracts/Percentage.sol

/**
 * @title Percentage
 * @author Roberto Cano
 * @notice Custom type for Percentage values with associated utility functions
 * @dev This contract defines a custom Percentage type and overloaded operators
 *      to perform arithmetic and comparison operations on Percentage values.
 */

/**
 * @dev Custom percentage type as uint256
 * @notice This type is used to represent percentage values with high precision
 */
type Percentage is uint256;

/**
 * @dev Overridden operators declaration for Percentage
 * @notice These operators allow for intuitive arithmetic and comparison operations
 *         on Percentage values
 */
using {
    add_0 as +,
    subtract as -,
    multiply as *,
    divide as /,
    lessOrEqualThan as <=,
    lessThan as <,
    greaterOrEqualThan as >=,
    greaterThan as >,
    equalTo as ==
} for Percentage global;

/**
 * @dev The number of decimals used for the percentage
 *  This constant defines the precision of the Percentage type
 */
uint256 constant PERCENTAGE_DECIMALS = 18;

/**
 * @dev The factor used to scale the percentage
 *  This constant is used to convert between human-readable percentages
 *         and the internal representation
 */
uint256 constant PERCENTAGE_FACTOR = 10 ** PERCENTAGE_DECIMALS;

/**
 * @dev Percentage of 100% with the given `PERCENTAGE_DECIMALS`
 *  This constant represents 100% in the Percentage type
 */
Percentage constant PERCENTAGE_100 = Percentage.wrap(100 * PERCENTAGE_FACTOR);

/**
 * OPERATOR FUNCTIONS
 */

/**
 * @dev Adds two Percentage values
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return The sum of a and b as a Percentage
 */
function add_0(Percentage a, Percentage b) pure returns (Percentage) {
    return Percentage.wrap(Percentage.unwrap(a) + Percentage.unwrap(b));
}

/**
 * @dev Subtracts one Percentage value from another
 * @param a The Percentage value to subtract from
 * @param b The Percentage value to subtract
 * @return The difference between a and b as a Percentage
 */
function subtract(Percentage a, Percentage b) pure returns (Percentage) {
    return Percentage.wrap(Percentage.unwrap(a) - Percentage.unwrap(b));
}

/**
 * @dev Multiplies two Percentage values
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return The product of a and b as a Percentage, scaled appropriately
 */
function multiply(Percentage a, Percentage b) pure returns (Percentage) {
    return
        Percentage.wrap(
            (Percentage.unwrap(a) * Percentage.unwrap(b)) /
                Percentage.unwrap(PERCENTAGE_100)
        );
}

/**
 * @dev Divides one Percentage value by another
 * @param a The Percentage value to divide
 * @param b The Percentage value to divide by
 * @return The quotient of a divided by b as a Percentage, scaled appropriately
 */
function divide(Percentage a, Percentage b) pure returns (Percentage) {
    return
        Percentage.wrap(
            (Percentage.unwrap(a) * Percentage.unwrap(PERCENTAGE_100)) /
                Percentage.unwrap(b)
        );
}

/**
 * @dev Checks if one Percentage value is less than or equal to another
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is less than or equal to b, false otherwise
 */
function lessOrEqualThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) <= Percentage.unwrap(b);
}

/**
 * @dev Checks if one Percentage value is less than another
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is less than b, false otherwise
 */
function lessThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) < Percentage.unwrap(b);
}

/**
 * @dev Checks if one Percentage value is greater than or equal to another
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is greater than or equal to b, false otherwise
 */
function greaterOrEqualThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) >= Percentage.unwrap(b);
}

/**
 * @dev Checks if one Percentage value is greater than another
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is greater than b, false otherwise
 */
function greaterThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) > Percentage.unwrap(b);
}

/**
 * @dev Checks if two Percentage values are equal
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is equal to b, false otherwise
 */
function equalTo(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) == Percentage.unwrap(b);
}

/**
 * @dev Alias for equalTo function
 * @param a The first Percentage value
 * @param b The second Percentage value
 * @return True if a is equal to b, false otherwise
 */
function equals(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) == Percentage.unwrap(b);
}

/**
 * @dev Converts a uint256 value to a Percentage
 * @param value The uint256 value to convert
 * @return The input value as a Percentage
 */
function toPercentage(uint256 value) pure returns (Percentage) {
    return Percentage.wrap(value * PERCENTAGE_FACTOR);
}

/**
 * @dev Converts a Percentage value to a uint256
 * @param value The Percentage value to convert
 * @return The Percentage value as a uint256
 */
function fromPercentage(Percentage value) pure returns (uint256) {
    return Percentage.unwrap(value) / PERCENTAGE_FACTOR;
}

// node_modules/@summerfi/rewards-contracts/src/interfaces/IStakingRewardsManagerBaseErrors.sol

/* @title IStakingRewardsManagerBaseErrors
 * @notice Interface defining custom errors for the Staking Rewards Manager
 */
interface IStakingRewardsManagerBaseErrors {
    /* @notice Thrown when attempting to stake zero tokens */
    error CannotStakeZero();

    /* @notice Thrown when attempting to withdraw zero tokens */
    error CannotWithdrawZero();

    /* @notice Thrown when the provided reward amount is too high */
    error ProvidedRewardTooHigh();

    /* @notice Thrown when trying to set rewards before the current period is complete */
    error RewardPeriodNotComplete();

    /* @notice Thrown when there are no reward tokens set */
    error NoRewardTokens();

    /* @notice Thrown when trying to add a reward token that already exists */
    error RewardTokenAlreadyExists();

    /* @notice Thrown when setting an invalid rewards duration */
    error InvalidRewardsDuration();

    /* @notice Thrown when trying to interact with a reward token that hasn't been initialized */
    error RewardTokenNotInitialized();

    /* @notice Thrown when the reward amount is invalid for the given duration
     * @param rewardToken The address of the reward token
     * @param rewardsDuration The duration for which the reward is invalid
     */
    error InvalidRewardAmount(address rewardToken, uint256 rewardsDuration);

    /* @notice Thrown when trying to interact with the staking token before it's initialized */
    error StakingTokenNotInitialized();

    /* @notice Thrown when trying to remove a reward token that doesn't exist */
    error RewardTokenDoesNotExist();

    /* @notice Thrown when trying to change the rewards duration of a reward token */
    error CannotChangeRewardsDuration();

    /* @notice Thrown when a reward token still has a balance */
    error RewardTokenStillHasBalance(uint256 balance);

    /* @notice Thrown when the index is out of bounds */
    error IndexOutOfBounds();

    /* @notice Thrown when the rewards duration is zero */
    error RewardsDurationCannotBeZero();

    /* @notice Thrown when attempting to unstake zero tokens */
    error CannotUnstakeZero();

    /* @notice Thrown when the rewards duration is too long */
    error RewardsDurationTooLong();

    /**
     * @notice Thrown when the receiver is the zero address
     */
    error CannotStakeToZeroAddress();
}

// src/errors/IArkConfigProviderErrors.sol

/**
 * @title IArkConfigProviderErrors
 * @dev This file contains custom error definitions for the ArkConfigProvider contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IArkConfigProviderErrors {
    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a configuration manager.
     */
    error CannotDeployArkWithoutConfigurationManager();

    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a Raft address.
     */
    error CannotDeployArkWithoutRaft();

    /**
     * @notice Thrown when attempting to deploy an Ark without specifying a token address.
     */
    error CannotDeployArkWithoutToken();

    /**
     * @notice Thrown when attempting to deploy an Ark with an empty name.
     */
    error CannotDeployArkWithEmptyName();

    /**
     * @notice Thrown when an invalid vault address is provided.
     */
    error InvalidVaultAddress();

    /**
     * @notice Thrown when there's a mismatch between expected and actual assets in an ERC4626 operation.
     */
    error ERC4626AssetMismatch();

    /**
     * @notice Thrown when the max deposit percentage of TVL is greater than 100%.
     */
    error MaxDepositPercentageOfTVLTooHigh();

    /**
     * @notice Thrown when attempting to register a FleetCommander when one is already registered.
     */
    error FleetCommanderAlreadyRegistered();

    /**
     * @notice Thrown when attempting to unregister a FleetCommander by a non-registered address.
     */
    error FleetCommanderNotRegistered();
}

// src/errors/IArkErrors.sol

/**
 * @title IArkErrors
 * @dev This file contains custom error definitions for the Ark contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IArkErrors {
    /**
     * @notice Thrown when attempting to remove a commander from an Ark that still has assets.
     */
    error CannotRemoveCommanderFromArkWithAssets();

    /**
     * @notice Thrown when trying to add a commander to an Ark that already has one.
     */
    error CannotAddCommanderToArkWithCommander();

    /**
     * @notice Thrown when attempting to use keeper data when it's not required.
     */
    error CannotUseKeeperDataWhenNotRequired();

    /**
     * @notice Thrown when keeper data is required but not provided.
     */
    error KeeperDataRequired();

    /**
     * @notice Thrown when invalid board data is provided.
     */
    error InvalidBoardData();

    /**
     * @notice Thrown when invalid disembark data is provided.
     */
    error InvalidDisembarkData();
}

// src/errors/IConfigurationManagerErrors.sol

/**
 * @title IConfigurationManagerErrors
 * @dev This file contains custom error definitions for the ConfigurationManager contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IConfigurationManagerErrors {
    /**
     * @notice Thrown when an operation is attempted with a zero address where a non-zero address is required.
     */
    error ZeroAddress();
    /**
     * @notice Thrown when ConfigurationManager was already initialized.
     */
    error ConfigurationManagerAlreadyInitialized();

    /**
     * @notice Thrown when the Raft address is not set.
     */
    error RaftNotSet();

    /**
     * @notice Thrown when the TipJar address is not set.
     */
    error TipJarNotSet();

    /**
     * @notice Thrown when the Treasury address is not set.
     */
    error TreasuryNotSet();

    /**
     * @notice Thrown when constructor address is set to the zero address.
     */
    error AddressZero();

    /**
     * @notice Thrown when the HarborCommand address is not set.
     */
    error HarborCommandNotSet();
}

// src/errors/IFleetCommanderConfigProviderErrors.sol

/**
 * @title IFleetCommanderConfigProviderErrors
 * @dev This file contains custom error definitions for the FleetCommanderConfigProvider contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IFleetCommanderConfigProviderErrors {
    /**
     * @notice Thrown when an operation is attempted on a non-existent Ark
     * @param ark The address of the Ark that was not found
     */
    error FleetCommanderArkNotFound(address ark);

    /**
     * @notice Thrown when trying to remove an Ark that still has a non-zero deposit cap
     * @param ark The address of the Ark with a non-zero deposit cap
     */
    error FleetCommanderArkDepositCapGreaterThanZero(address ark);

    /**
     * @notice Thrown when attempting to remove an Ark that still holds assets
     * @param ark The address of the Ark with non-zero assets
     */
    error FleetCommanderArkAssetsNotZero(address ark);

    /**
     * @notice Thrown when trying to add an Ark that already exists in the system
     * @param ark The address of the Ark that already exists
     */
    error FleetCommanderArkAlreadyExists(address ark);

    /**
     * @notice Thrown when an invalid Ark address is provided (e.g., zero address)
     */
    error FleetCommanderInvalidArkAddress();

    /**
     * @notice Thrown when trying to set a StakingRewardsManager to the zero address
     */
    error FleetCommanderInvalidStakingRewardsManager();

    /**
     * @notice Thrown when trying to set a max rebalance operations to a value greater than the max allowed
     * @param newMaxRebalanceOperations The new max rebalance operations value
     */
    error FleetCommanderMaxRebalanceOperationsTooHigh(
        uint256 newMaxRebalanceOperations
    );

    /**
     * @notice Thrown when the asset of the Ark does not match the asset of the FleetCommander
     */
    error FleetCommanderAssetMismatch();
}

// src/errors/IFleetCommanderErrors.sol

/**
 * @title IFleetCommanderErrors
 * @dev This file contains custom error definitions for the FleetCommander contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IFleetCommanderErrors {
    /**
     * @notice Thrown when transfers are disabled.
     */
    error FleetCommanderTransfersDisabled();

    /**
     * @notice Thrown when an operation is attempted on an inactive Ark.
     * @param ark The address of the inactive Ark.
     */
    error FleetCommanderArkNotActive(address ark);

    /**
     * @notice Thrown when attempting to rebalance to an invalid Ark.
     * @param ark The address of the invalid Ark.
     * @param amount Amount of tokens added to target ark
     * @param effectiveDepositCap Effective deposit cap of the ark (minimum of % of fleet TVL or arbitrary ark deposit
     * cap)
     */
    error FleetCommanderEffectiveDepositCapExceeded(
        address ark,
        uint256 amount,
        uint256 effectiveDepositCap
    );

    /**
     * @notice Thrown when there is insufficient buffer for an operation.
     */
    error FleetCommanderInsufficientBuffer();

    /**
     * @notice Thrown when a rebalance operation is attempted with no actual operations.
     */
    error FleetCommanderRebalanceNoOperations();

    /**
     * @notice Thrown when a rebalance operation exceeds the maximum allowed number of operations.
     * @param operationsCount The number of operations attempted.
     */
    error FleetCommanderRebalanceTooManyOperations(uint256 operationsCount);

    /**
     * @notice Thrown when a rebalance amount for an Ark is zero.
     * @param ark The address of the Ark with zero rebalance amount.
     */
    error FleetCommanderRebalanceAmountZero(address ark);

    /**
     * @notice Thrown when a withdrawal amount exceeds the maximum buffer limit.
     */
    error WithdrawalAmountExceedsMaxBufferLimit();

    /**
     * @notice Thrown when an Ark's deposit cap is zero.
     * @param ark The address of the Ark with zero deposit cap.
     */
    error FleetCommanderArkDepositCapZero(address ark);

    /**
     * @notice Thrown when no funds were moved in an operation that expected fund movement.
     */
    error FleetCommanderNoFundsMoved();

    /**
     * @notice Thrown when there are no excess funds to perform an operation.
     */
    error FleetCommanderNoExcessFunds();

    /**
     * @notice Thrown when an invalid source Ark is specified for an operation.
     * @param ark The address of the invalid source Ark.
     */
    error FleetCommanderInvalidSourceArk(address ark);

    /**
     * @notice Thrown when an operation attempts to move more funds than available.
     */
    error FleetCommanderMovedMoreThanAvailable();

    /**
     * @notice Thrown when an unauthorized withdrawal is attempted.
     * @param caller The address attempting the withdrawal.
     * @param owner The address of the authorized owner.
     */
    error FleetCommanderUnauthorizedWithdrawal(address caller, address owner);

    /**
     * @notice Thrown when an unauthorized redemption is attempted.
     * @param caller The address attempting the redemption.
     * @param owner The address of the authorized owner.
     */
    error FleetCommanderUnauthorizedRedemption(address caller, address owner);

    /**
     * @notice Thrown when attempting to use rebalance on a buffer Ark.
     */
    error FleetCommanderCantUseRebalanceOnBufferArk();

    /**
     * @notice Thrown when attempting to use the maximum uint value for buffer adjustment from buffer.
     */
    error FleetCommanderCantUseMaxUintMovingFromBuffer();

    /**
     * @notice Thrown when a rebalance operation exceeds the maximum outflow for an Ark.
     * @param fromArk The address of the Ark from which funds are being moved.
     * @param amount The amount being moved.
     * @param maxRebalanceOutflow The maximum allowed outflow.
     */
    error FleetCommanderExceedsMaxOutflow(
        address fromArk,
        uint256 amount,
        uint256 maxRebalanceOutflow
    );

    /**
     * @notice Thrown when a rebalance operation exceeds the maximum inflow for an Ark.
     * @param fromArk The address of the Ark to which funds are being moved.
     * @param amount The amount being moved.
     * @param maxRebalanceInflow The maximum allowed inflow.
     */
    error FleetCommanderExceedsMaxInflow(
        address fromArk,
        uint256 amount,
        uint256 maxRebalanceInflow
    );

    /**
     * @notice Thrown when the staking rewards manager is not set.
     */
    error FleetCommanderStakingRewardsManagerNotSet();

    /**
     * @notice Thrown when user attempts to deposit/mint or withdraw/redeem 0 units
     */
    error FleetCommanderZeroAmount();
}

// src/errors/IRaftErrors.sol

/**
 * @title IRaftErrors
 * @dev This file contains custom error definitions for the Raft contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IRaftErrors {
    /**
     * @notice Thrown when attempting to start an auction for an Ark and reward token pair that already has an active
     * auction
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     */
    error RaftAuctionAlreadyRunning(address ark, address rewardToken);

    /**
     * @notice Thrown when attempting to board rewards to an Ark that does not require keeper data
     * @param ark The address of the Ark
     */
    error RaftArkRequiresKeeperData(address ark);

    /**
     * @notice Thrown when attempting to board rewards to an Ark that requires keeper data
     * @param ark The address of the Ark
     */
    error RaftArkDoesntRequireKeeperData(address ark);

    /**
     * @notice Thrown when attempting to sweep a token that is not sweepable for an Ark
     * @param ark The address of the Ark
     * @param token The address of the token
     */
    error RaftTokenNotSweepable(address ark, address token);

    /**
     * @notice Thrown when attempting to start an auction for an Ark and reward token pair that has no parameters set
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     */
    error RaftAuctionParametersNotSet(address ark, address rewardToken);

    /**
     * @notice Thrown when attempting to set invalid auction parameters
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     */
    error RaftInvalidAuctionParameters(address ark, address rewardToken);
}

// src/events/IArkEvents.sol

/**
 * @title IArkEvents
 * @notice Interface for events emitted by Ark contracts
 */
interface IArkEvents {
    /**
     * @notice Emitted when rewards are harvested from an Ark
     * @param rewardTokens The addresses of the harvested reward tokens
     * @param rewardAmounts The amounts of the harvested reward tokens
     */
    event ArkHarvested(
        address[] indexed rewardTokens,
        uint256[] indexed rewardAmounts
    );

    /**
     * @notice Emitted when tokens are boarded (deposited) into the Ark
     * @param commander The address of the FleetCommander initiating the boarding
     * @param token The address of the token being boarded
     * @param amount The amount of tokens boarded
     */
    event Boarded(address indexed commander, address token, uint256 amount);

    /**
     * @notice Emitted when tokens are disembarked (withdrawn) from the Ark
     * @param commander The address of the FleetCommander initiating the disembarking
     * @param token The address of the token being disembarked
     * @param amount The amount of tokens disembarked
     */
    event Disembarked(address indexed commander, address token, uint256 amount);

    /**
     * @notice Emitted when tokens are moved from one address to another
     * @param from Ark being boarded from
     * @param to Ark being boarded to
     * @param token The address of the token being moved
     * @param amount The amount of tokens moved
     */
    event Moved(
        address indexed from,
        address indexed to,
        address token,
        uint256 amount
    );

    /**
     * @notice Emitted when the Ark is poked and the share price is updated
     * @param currentPrice Current share price of the Ark
     * @param timestamp The timestamp of the poke
     */
    event ArkPoked(uint256 currentPrice, uint256 timestamp);

    /**
     * @notice Emitted when the Ark is swept
     * @param sweptTokens The addresses of the swept tokens
     * @param sweptAmounts The amounts of the swept tokens
     */
    event ArkSwept(
        address[] indexed sweptTokens,
        uint256[] indexed sweptAmounts
    );
}

// src/events/IConfigurationManagerEvents.sol

/**
 * @title IConfigurationManagerEvents
 * @notice Interface for events emitted by the Configuration Manager
 */
interface IConfigurationManagerEvents {
    /**
     * @notice Emitted when the Raft address is updated
     * @param newRaft The address of the new Raft
     */
    event RaftUpdated(address oldRaft, address newRaft);

    /**
     * @notice Emitted when the tip jar address is updated
     * @param newTipJar The address of the new tip jar
     */
    event TipJarUpdated(address oldTipJar, address newTipJar);

    /**
     * @notice Emitted when the tip rate is updated
     * @param newTipRate The new tip rate value
     */
    event TipRateUpdated(uint8 oldTipRate, uint8 newTipRate);

    /**
     * @notice Emitted when the Treasury address is updated
     * @param newTreasury The address of the new Treasury
     */
    event TreasuryUpdated(address oldTreasury, address newTreasury);

    /**
     * @notice Emitted when the Harbor Command address is updated
     * @param oldHarborCommand The address of the old Harbor Command
     * @param newHarborCommand The address of the new Harbor Command
     */
    event HarborCommandUpdated(
        address oldHarborCommand,
        address newHarborCommand
    );

    /**
     * @notice Emitted when the Fleet Commander Rewards Manager Factory address is updated
     * @param oldFleetCommanderRewardsManagerFactory The address of the old Fleet Commander Rewards Manager Factory
     * @param newFleetCommanderRewardsManagerFactory The address of the new Fleet Commander Rewards Manager Factory
     */
    event FleetCommanderRewardsManagerFactoryUpdated(
        address oldFleetCommanderRewardsManagerFactory,
        address newFleetCommanderRewardsManagerFactory
    );
}

// src/events/IFleetCommanderConfigProviderEvents.sol

interface IFleetCommanderConfigProviderEvents {
    /**
     * @notice Emitted when the deposit cap is updated
     * @param newCap The new deposit cap value
     */
    event FleetCommanderDepositCapUpdated(uint256 newCap);
    /**
     * @notice Emitted when a new Ark is added
     * @param ark The address of the newly added Ark
     */
    event ArkAdded(address indexed ark);

    /**
     * @notice Emitted when an Ark is removed
     * @param ark The address of the removed Ark
     */
    event ArkRemoved(address indexed ark);
    /**
     * @notice Emitted when new minimum funds buffer balance is set
     * @param newBalance New minimum funds buffer balance
     */
    event FleetCommanderminimumBufferBalanceUpdated(uint256 newBalance);

    /**
     * @notice Emitted when new max allowed rebalance operations is set
     * @param newMaxRebalanceOperations Max allowed rebalance operations
     */
    event FleetCommanderMaxRebalanceOperationsUpdated(
        uint256 newMaxRebalanceOperations
    );

    /**
     * @notice Emitted when the staking rewards contract address is updated
     * @param newStakingRewards The address of the new staking rewards contract
     */
    event FleetCommanderStakingRewardsUpdated(address newStakingRewards);

    /**
     * @notice Emitted when the transfer enabled status is updated
     */
    event TransfersEnabled();
}

// src/interfaces/IArkAccessManaged.sol

/**
 * @title IArkAccessManaged
 * @notice Extends the ProtocolAccessManaged contract with Ark specific AccessControl
 *         Used to specifically tie one FleetCommander to each Ark
 *
 * @dev One Ark specific role is defined:
 *   - Commander: is the fleet commander contract itself and couples an
 *        Ark to specific Fleet Commander
 *
 *   The Commander role is still declared on the access manager to centralise
 *   role definitions.
 */
interface IArkAccessManaged {}

// src/types/ConfigurationManagerTypes.sol

/**
 * @notice Initialization parameters for the ConfigurationManager contract
 */
struct ConfigurationManagerParams {
    address raft;
    address tipJar;
    address treasury;
    address harborCommand;
    address fleetCommanderRewardsManagerFactory;
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata
    ) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// node_modules/@summerfi/dutch-auction/src/lib/TokenLibrary.sol

/**
 * @title Token Library
 * @author halaprix
 * @notice This library provides utility functions for handling token decimals and conversions
 * @dev Implements functions to get token decimals and convert amounts between different decimal representations
 */
library TokenLibrary {
    /**
     * @notice Retrieves the number of decimals for a given token
     * @dev Uses a low-level call to get the decimals, defaulting to 18 if the call fails
     * @param token The ERC20 token to query
     * @return The number of decimals for the token
     *
     * @dev Process:
     * 1. Attempts to call the 'decimals()' function on the token contract
     * 2. If the call succeeds, decodes and returns the result
     * 3. If the call fails, returns 18 as a default value
     *
     * @dev Note: This function assumes that tokens follow the ERC20 standard.
     * Non-standard tokens may cause unexpected behavior.
     */
    function getDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeWithSignature("decimals()")
        );

        // If the call was successful and returned data
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }

        // If the call was successful but returned no data, or if the call failed
        return 18;
    }

    /**
     * @notice Converts an amount from its original decimal representation to 18 decimals (wei)
     * @dev Adjusts the amount based on the difference between the original decimals and 18
     * @param amount The amount to convert
     * @param decimals The original number of decimals
     * @return The amount converted to 18 decimal representation
     *
     * @dev Calculation:
     * - If decimals == 18, no conversion needed
     * - If decimals > 18, divide by 10^(decimals - 18)
     * - If decimals < 18, multiply by 10^(18 - decimals)
     *
     * @dev Note: This function assumes that the input amount is in its original decimal representation.
     * Incorrect input decimals will lead to incorrect conversions.
     */
    function toWei(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount / (10 ** (decimals - 18));
        return amount * (10 ** (18 - decimals));
    }

    /**
     * @notice Converts an amount from 18 decimals (wei) to a specified decimal representation
     * @dev Adjusts the amount based on the difference between 18 and the target decimals
     * @param amount The amount in 18 decimal representation to convert
     * @param decimals The target number of decimals
     * @return The amount converted to the specified decimal representation
     *
     * @dev Calculation:
     * - If decimals == 18, no conversion needed
     * - If decimals > 18, multiply by 10^(decimals - 18)
     * - If decimals < 18, divide by 10^(18 - decimals)
     *
     * @dev Note: This function assumes that the input amount is in 18 decimal representation.
     * Incorrect input amounts will lead to incorrect conversions.
     */
    function fromWei(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount * (10 ** (decimals - 18));
        return amount / (10 ** (18 - decimals));
    }

    /**
     * @notice Converts an amount from one decimal representation to another
     * @dev Performs the conversion directly to avoid precision loss
     * @param amount The amount to convert
     * @param fromDecimals The original number of decimals
     * @param toDecimals The target number of decimals
     * @return The amount converted to the target decimal representation
     *
     * @dev Process:
     * 1. If fromDecimals == toDecimals, no conversion needed
     * 2. If fromDecimals < toDecimals, multiply by 10^(toDecimals - fromDecimals)
     * 3. If fromDecimals > toDecimals, divide by 10^(fromDecimals - toDecimals)
     *
     * @dev Note: This function provides a more precise way to convert between any two decimal representations.
     * It avoids the intermediate step of converting to 18 decimals, which can cause precision loss.
     */
    function convertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return amount;

        if (fromDecimals < toDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            return amount / (10 ** (fromDecimals - toDecimals));
        }
    }
}

// node_modules/@summerfi/percentage-solidity/contracts/PercentageUtils.sol

/**
 * @title PercentageUtils
 * @author Roberto Cano
 * @notice Utility library to apply percentage calculations to input amounts
 * @dev This library provides functions for adding, subtracting, and applying
 *      percentages to amounts, as well as utility functions for working with
 *      percentages.
 */
library PercentageUtils {
    /**
     * @notice Adds the percentage to the given amount and returns the result
     * @param amount The base amount to which the percentage will be added
     * @param percentage The percentage to add to the amount
     * @return The amount after the percentage is applied
     * @dev It performs the following operation: (100.0% + percentage) * amount
     */
    function addPercentage(
        uint256 amount,
        Percentage percentage
    ) internal pure returns (uint256) {
        return applyPercentage(amount, PERCENTAGE_100 + percentage);
    }

    /**
     * @notice Subtracts the percentage from the given amount and returns the result
     * @param amount The base amount from which the percentage will be subtracted
     * @param percentage The percentage to subtract from the amount
     * @return The amount after the percentage is applied
     * @dev It performs the following operation: (100.0% - percentage) * amount
     */
    function subtractPercentage(
        uint256 amount,
        Percentage percentage
    ) internal pure returns (uint256) {
        return applyPercentage(amount, PERCENTAGE_100 - percentage);
    }

    /**
     * @notice Applies the given percentage to the given amount and returns the result
     * @param amount The amount to apply the percentage to
     * @param percentage The percentage to apply to the amount
     * @return The amount after the percentage is applied
     * @dev This function is used internally by addPercentage and subtractPercentage
     */
    function applyPercentage(
        uint256 amount,
        Percentage percentage
    ) internal pure returns (uint256) {
        return
            (amount * Percentage.unwrap(percentage)) /
            Percentage.unwrap(PERCENTAGE_100);
    }

    /**
     * @notice Checks if the given percentage is in range, this is, if it is between 0 and 100
     * @param percentage The percentage to check
     * @return True if the percentage is in range, false otherwise
     * @dev This function is useful for validating input percentages
     */
    function isPercentageInRange(
        Percentage percentage
    ) internal pure returns (bool) {
        return percentage <= PERCENTAGE_100;
    }

    /**
     * @notice Converts the given fraction into a percentage with the right number of decimals
     * @param numerator The numerator of the fraction
     * @param denominator The denominator of the fraction
     * @return The percentage with `PERCENTAGE_DECIMALS` decimals
     * @dev This function is useful for converting ratios to percentages
     *     For example, fromFraction(1, 2) returns 50%
     */
    function fromFraction(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (Percentage) {
        return
            Percentage.wrap(
                (numerator * PERCENTAGE_FACTOR * 100) / denominator
            );
    }

    /**
     * @notice Converts the given integer into a percentage
     * @param percentage The percentage in human-readable format, i.e., 50 for 50%
     * @return The percentage with `PERCENTAGE_DECIMALS` decimals
     * @dev This function is useful for converting human-readable percentages to the internal representation
     */
    function fromIntegerPercentage(
        uint256 percentage
    ) internal pure returns (Percentage) {
        return toPercentage(percentage);
    }
}

// src/events/IArkConfigProviderEvents.sol

/**
 * @title IArkConfigProviderEvents
 * @notice Interface for events emitted by ArkConfigProvider contracts
 */
interface IArkConfigProviderEvents {
    /**
     * @notice Emitted when the deposit cap of the Ark is updated
     * @param newCap The new deposit cap value
     */
    event DepositCapUpdated(uint256 newCap);

    /**
     * @notice Emitted when the maximum deposit percentage of TVL is updated
     * @param newMaxDepositPercentageOfTVL The new maximum deposit percentage of TVL
     */
    event MaxDepositPercentageOfTVLUpdated(
        Percentage newMaxDepositPercentageOfTVL
    );

    /**
     * @notice Emitted when the Raft address associated with the Ark is updated
     * @param newRaft The address of the new Raft
     */
    event RaftUpdated(address newRaft);

    /**
     * @notice Emitted when the maximum outflow limit for the Ark during rebalancing is updated
     * @param newMaxOutflow The new maximum amount that can be transferred out of the Ark during a rebalance
     */
    event MaxRebalanceOutflowUpdated(uint256 newMaxOutflow);

    /**
     * @notice Emitted when the maximum inflow limit for the Ark during rebalancing is updated
     * @param newMaxInflow The new maximum amount that can be transferred into the Ark during a rebalance
     */
    event MaxRebalanceInflowUpdated(uint256 newMaxInflow);

    /**
     * @notice Emitted when the Fleet Commander is registered
     * @param commander The address of the Fleet Commander
     */
    event FleetCommanderRegistered(address commander);

    /**
     * @notice Emitted when the Fleet Commander is unregistered
     * @param commander The address of the Fleet Commander
     */
    event FleetCommanderUnregistered(address commander);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC4626.sol)

/**
 * @dev Interface of the ERC-4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(
        uint256 assets
    ) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(
        address receiver
    ) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(
        uint256 assets
    ) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(
        address receiver
    ) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(
        address owner
    ) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(
        uint256 shares
    ) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an success flag (no overflow).
     */
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an success flag (no overflow).
     */
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an success flag (no overflow).
     */
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool success, uint256 result) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a success flag (no division by zero).
     */
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(
        bool condition,
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * SafeCast.toUint(condition));
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a < b, a, b);
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }

        // The following calculation ensures accurate ceiling division without overflow.
        // Since a is non-zero, (a - 1) / b will not overflow.
        // The largest possible result occurs when (a - 1) / b is type(uint256).max,
        // but the largest value we can obtain is type(uint256).max - 1, which happens
        // when a = type(uint256).max and b = 1.
        unchecked {
            return SafeCast.toUint(a > 0) * ((a - 1) / b + 1);
        }
    }

    /**
     * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     *
     * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
            // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2²⁵⁶ + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= prod1) {
                Panic.panic(
                    ternary(
                        denominator == 0,
                        Panic.DIVISION_BY_ZERO,
                        Panic.UNDER_OVERFLOW
                    )
                );
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        return
            mulDiv(x, y, denominator) +
            SafeCast.toUint(
                unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0
            );
    }

    /**
     * @dev Calculate the modular multiplicative inverse of a number in Z/nZ.
     *
     * If n is a prime, then Z/nZ is a field. In that case all elements are inversible, except 0.
     * If n is not a prime, then Z/nZ is not a field, and some elements might not be inversible.
     *
     * If the input value is not inversible, 0 is returned.
     *
     * NOTE: If you know for sure that n is (big) a prime, it may be cheaper to use Fermat's little theorem and get the
     * inverse using `Math.modExp(a, n - 2, n)`. See {invModPrime}.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            // The inverse modulo is calculated using the Extended Euclidean Algorithm (iterative version)
            // Used to compute integers x and y such that: ax + ny = gcd(a, n).
            // When the gcd is 1, then the inverse of a modulo n exists and it's x.
            // ax + ny = 1
            // ax = 1 + (-y)n
            // ax ≡ 1 (mod n) # x is the inverse of a modulo n

            // If the remainder is 0 the gcd is n right away.
            uint256 remainder = a % n;
            uint256 gcd = n;

            // Therefore the initial coefficients are:
            // ax + ny = gcd(a, n) = n
            // 0a + 1n = n
            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (
                    // The old remainder is the next gcd to try.
                    remainder,
                    // Compute the next remainder.
                    // Can't overflow given that (a % gcd) * (gcd // (a % gcd)) <= gcd
                    // where gcd is at most n (capped to type(uint256).max)
                    gcd - remainder * quotient
                );

                (x, y) = (
                    // Increment the coefficient of a.
                    y,
                    // Decrement the coefficient of n.
                    // Can overflow, but the result is casted to uint256 so that the
                    // next value of y is "wrapped around" to a value between 0 and n - 1.
                    x - y * int256(quotient)
                );
            }

            if (gcd != 1) return 0; // No inverse exists.
            return ternary(x < 0, n - uint256(-x), uint256(x)); // Wrap the result if it's negative.
        }
    }

    /**
     * @dev Variant of {invMod}. More efficient, but only works if `p` is known to be a prime greater than `2`.
     *
     * From https://en.wikipedia.org/wiki/Fermat%27s_little_theorem[Fermat's little theorem], we know that if p is
     * prime, then `a**(p-1) ≡ 1 mod p`. As a consequence, we have `a * a**(p-2) ≡ 1 mod p`, which means that
     * `a**(p-2)` is the modular multiplicative inverse of a in Fp.
     *
     * NOTE: this function does NOT check that `p` is a prime greater than `2`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return Math.modExp(a, p - 2, p);
        }
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m)
     *
     * Requirements:
     * - modulus can't be zero
     * - underlying staticcall to precompile must succeed
     *
     * IMPORTANT: The result is only valid if the underlying call succeeds. When using this function, make
     * sure the chain you're using it on supports the precompiled contract for modular exponentiation
     * at address 0x05 as specified in https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise,
     * the underlying function will succeed given the lack of a revert, but the result may be incorrectly
     * interpreted as 0.
     */
    function modExp(
        uint256 b,
        uint256 e,
        uint256 m
    ) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m).
     * It includes a success flag indicating if the operation succeeded. Operation will be marked as failed if trying
     * to operate modulo 0 or if the underlying precompile reverted.
     *
     * IMPORTANT: The result is only valid if the success flag is true. When using this function, make sure the chain
     * you're using it on supports the precompiled contract for modular exponentiation at address 0x05 as specified in
     * https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise, the underlying function will succeed given the lack
     * of a revert, but the result may be incorrectly interpreted as 0.
     */
    function tryModExp(
        uint256 b,
        uint256 e,
        uint256 m
    ) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // | Offset    | Content    | Content (Hex)                                                      |
            // |-----------|------------|--------------------------------------------------------------------|
            // | 0x00:0x1f | size of b  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x20:0x3f | size of e  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x40:0x5f | size of m  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x60:0x7f | value of b | 0x<.............................................................b> |
            // | 0x80:0x9f | value of e | 0x<.............................................................e> |
            // | 0xa0:0xbf | value of m | 0x<.............................................................m> |
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)

            // Given the result < m, it's guaranteed to fit in 32 bytes,
            // so we can use the memory scratch space located at offset 0.
            success := staticcall(gas(), 0x05, ptr, 0xc0, 0x00, 0x20)
            result := mload(0x00)
        }
    }

    /**
     * @dev Variant of {modExp} that supports inputs of arbitrary length.
     */
    function modExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Variant of {tryModExp} that supports inputs of arbitrary length.
     */
    function tryModExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));

        uint256 mLen = m.length;

        // Encode call args in result and move the free memory pointer
        result = abi.encodePacked(b.length, e.length, mLen, b, e, m);

        assembly ("memory-safe") {
            let dataPtr := add(result, 0x20)
            // Write result on top of args to avoid allocating extra memory.
            success := staticcall(
                gas(),
                0x05,
                dataPtr,
                mload(result),
                dataPtr,
                mLen
            )
            // Overwrite the length.
            // result.length > returndatasize() is guaranteed because returndatasize() == m.length
            mstore(result, mLen)
            // Set the memory pointer after the returned data.
            mstore(0x40, add(dataPtr, mLen))
        }
    }

    /**
     * @dev Returns whether the provided byte array is zero.
     */
    function _zeroBytes(bytes memory byteArray) private pure returns (bool) {
        for (uint256 i = 0; i < byteArray.length; ++i) {
            if (byteArray[i] != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * This method is based on Newton's method for computing square roots; the algorithm is restricted to only
     * using integer operations.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }

            // In this function, we use Newton's method to get a root of `f(x) := x² - a`. It involves building a
            // sequence x_n that converges toward sqrt(a). For each iteration x_n, we also define the error between
            // the current value as `ε_n = | x_n - sqrt(a) |`.
            //
            // For our first estimation, we consider `e` the smallest power of 2 which is bigger than the square root
            // of the target. (i.e. `2**(e-1) ≤ sqrt(a) < 2**e`). We know that `e ≤ 128` because `(2¹²⁸)² = 2²⁵⁶` is
            // bigger than any uint256.
            //
            // By noticing that
            // `2**(e-1) ≤ sqrt(a) < 2**e → (2**(e-1))² ≤ a < (2**e)² → 2**(2*e-2) ≤ a < 2**(2*e)`
            // we can deduce that `e - 1` is `log2(a) / 2`. We can thus compute `x_n = 2**(e-1)` using a method similar
            // to the msb function.
            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }

            // We now have x_n such that `x_n = 2**(e-1) ≤ sqrt(a) < 2**e = 2 * x_n`. This implies ε_n ≤ 2**(e-1).
            //
            // We can refine our estimation by noticing that the middle of that interval minimizes the error.
            // If we move x_n to equal 2**(e-1) + 2**(e-2), then we reduce the error to ε_n ≤ 2**(e-2).
            // This is going to be our x_0 (and ε_0)
            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)

            // From here, Newton's method give us:
            // x_{n+1} = (x_n + a / x_n) / 2
            //
            // One should note that:
            // x_{n+1}² - a = ((x_n + a / x_n) / 2)² - a
            //              = ((x_n² + a) / (2 * x_n))² - a
            //              = (x_n⁴ + 2 * a * x_n² + a²) / (4 * x_n²) - a
            //              = (x_n⁴ + 2 * a * x_n² + a² - 4 * a * x_n²) / (4 * x_n²)
            //              = (x_n⁴ - 2 * a * x_n² + a²) / (4 * x_n²)
            //              = (x_n² - a)² / (2 * x_n)²
            //              = ((x_n² - a) / (2 * x_n))²
            //              ≥ 0
            // Which proves that for all n ≥ 1, sqrt(a) ≤ x_n
            //
            // This gives us the proof of quadratic convergence of the sequence:
            // ε_{n+1} = | x_{n+1} - sqrt(a) |
            //         = | (x_n + a / x_n) / 2 - sqrt(a) |
            //         = | (x_n² + a - 2*x_n*sqrt(a)) / (2 * x_n) |
            //         = | (x_n - sqrt(a))² / (2 * x_n) |
            //         = | ε_n² / (2 * x_n) |
            //         = ε_n² / | (2 * x_n) |
            //
            // For the first iteration, we have a special case where x_0 is known:
            // ε_1 = ε_0² / | (2 * x_0) |
            //     ≤ (2**(e-2))² / (2 * (2**(e-1) + 2**(e-2)))
            //     ≤ 2**(2*e-4) / (3 * 2**(e-1))
            //     ≤ 2**(e-3) / 3
            //     ≤ 2**(e-3-log2(3))
            //     ≤ 2**(e-4.5)
            //
            // For the following iterations, we use the fact that, 2**(e-1) ≤ sqrt(a) ≤ x_n:
            // ε_{n+1} = ε_n² / | (2 * x_n) |
            //         ≤ (2**(e-k))² / (2 * 2**(e-1))
            //         ≤ 2**(2*e-2*k) / 2**e
            //         ≤ 2**(e-2*k)
            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

            // Because e ≤ 128 (as discussed during the first estimation phase), we know have reached a precision
            // ε_6 ≤ 2**(e-144) < 1. Given we're operating on integers, then we can ensure that xn is now either
            // sqrt(a) or sqrt(a) + 1.
            return xn - SafeCast.toUint(xn > a / xn);
        }
    }

    /**
     * @dev Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(
        uint256 a,
        Rounding rounding
    ) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return
                result +
                SafeCast.toUint(
                    unsignedRoundsUp(rounding) && result * result < a
                );
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        uint256 exp;
        unchecked {
            exp = 128 * SafeCast.toUint(value > (1 << 128) - 1);
            value >>= exp;
            result += exp;

            exp = 64 * SafeCast.toUint(value > (1 << 64) - 1);
            value >>= exp;
            result += exp;

            exp = 32 * SafeCast.toUint(value > (1 << 32) - 1);
            value >>= exp;
            result += exp;

            exp = 16 * SafeCast.toUint(value > (1 << 16) - 1);
            value >>= exp;
            result += exp;

            exp = 8 * SafeCast.toUint(value > (1 << 8) - 1);
            value >>= exp;
            result += exp;

            exp = 4 * SafeCast.toUint(value > (1 << 4) - 1);
            value >>= exp;
            result += exp;

            exp = 2 * SafeCast.toUint(value > (1 << 2) - 1);
            value >>= exp;
            result += exp;

            result += SafeCast.toUint(value > 1);
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(
        uint256 value,
        Rounding rounding
    ) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return
                result +
                SafeCast.toUint(
                    unsignedRoundsUp(rounding) && 1 << result < value
                );
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(
        uint256 value,
        Rounding rounding
    ) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return
                result +
                SafeCast.toUint(
                    unsignedRoundsUp(rounding) && 10 ** result < value
                );
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        uint256 isGt;
        unchecked {
            isGt = SafeCast.toUint(value > (1 << 128) - 1);
            value >>= isGt * 128;
            result += isGt * 16;

            isGt = SafeCast.toUint(value > (1 << 64) - 1);
            value >>= isGt * 64;
            result += isGt * 8;

            isGt = SafeCast.toUint(value > (1 << 32) - 1);
            value >>= isGt * 32;
            result += isGt * 4;

            isGt = SafeCast.toUint(value > (1 << 16) - 1);
            value >>= isGt * 16;
            result += isGt * 2;

            result += SafeCast.toUint(value > (1 << 8) - 1);
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(
        uint256 value,
        Rounding rounding
    ) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return
                result +
                SafeCast.toUint(
                    unsignedRoundsUp(rounding) && 1 << (result << 3) < value
                );
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// node_modules/@summerfi/rewards-contracts/src/interfaces/IStakingRewardsManagerBase.sol

/* @title IStakingRewardsManagerBase
 * @notice Interface for the Staking Rewards Manager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IStakingRewardsManagerBase is IStakingRewardsManagerBaseErrors {
    // Views

    /* @notice Get the total amount of staked tokens
     * @return The total supply of staked tokens
     */
    function totalSupply() external view returns (uint256);

    /* @notice Get the staked balance of a specific account
     * @param account The address of the account to check
     * @return The staked balance of the account
     */
    function balanceOf(address account) external view returns (uint256);

    /* @notice Get the last time the reward was applicable for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The timestamp of the last applicable reward time
     */
    function lastTimeRewardApplicable(
        address rewardToken
    ) external view returns (uint256);

    /* @notice Get the reward per token for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The reward amount per staked token (WAD-scaled)
     * @dev Returns a WAD-scaled value (1e18) to maintain precision in calculations
     * @dev This value represents: (rewardRate * timeElapsed * WAD) / totalSupply
     */
    function rewardPerToken(
        address rewardToken
    ) external view returns (uint256);

    /* @notice Calculate the earned reward for an account and a specific reward token
     * @param account The address of the account
     * @param rewardToken The address of the reward token
     * @return The amount of reward tokens earned (not WAD-scaled)
     * @dev Calculated as: (balance * (rewardPerToken - userRewardPerTokenPaid)) / WAD + rewards
     */
    function earned(
        address account,
        address rewardToken
    ) external view returns (uint256);

    /* @notice Get the reward for the entire duration for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The total reward amount for the duration (not WAD-scaled)
     * @dev Calculated as: (rewardRate * rewardsDuration) / WAD
     */
    function getRewardForDuration(
        address rewardToken
    ) external view returns (uint256);

    /* @notice Get the address of the staking token
     * @return The address of the staking token
     */
    function stakingToken() external view returns (address);

    /* @notice Get the reward token at a specific index
     * @param index The index of the reward token
     * @return The address of the reward token
     * @dev Reverts with IndexOutOfBounds if index >= rewardTokensLength()
     */
    function rewardTokens(uint256 index) external view returns (address);

    /* @notice Get the total number of reward tokens
     * @return The length of the reward tokens list
     */
    function rewardTokensLength() external view returns (uint256);

    /* @notice Check if a token is in the list of reward tokens
     * @param rewardToken The address to check
     * @return bool True if the token is a reward token, false otherwise
     */
    function isRewardToken(address rewardToken) external view returns (bool);

    // Mutative functions

    /* @notice Stake tokens for an account
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external;

    /* @notice Stake tokens for an account on behalf of another account
     * @param receiver The address of the account to stake for
     * @param amount The amount of tokens to stake
     */
    function stakeOnBehalfOf(address receiver, uint256 amount) external;

    /* @notice Unstake staked tokens on behalf of another account
     * @param owner The address of the account to unstake from
     * @param amount The amount of tokens to unstake
     * @param claimRewards Whether to claim rewards before unstaking
     */
    function unstakeAndWithdrawOnBehalfOf(
        address owner,
        uint256 amount,
        bool claimRewards
    ) external;

    /* @notice Unstake staked tokens
     * @param amount The amount of tokens to unstake
     */
    function unstake(uint256 amount) external;

    /* @notice Claim accumulated rewards for all reward tokens */
    function getReward() external;

    /* @notice Claim accumulated rewards for a specific reward token
     * @param rewardToken The address of the reward token to claim
     */
    function getReward(address rewardToken) external;

    /* @notice Withdraw all staked tokens and claim rewards */
    function exit() external;

    // Admin functions

    /* @notice Notify the contract about new reward amount
     * @param rewardToken The address of the reward token
     * @param reward The amount of new reward (not WAD-scaled)
     * @param newRewardsDuration The duration for rewards distribution (only used when adding a new reward token)
     * @dev Internally sets rewardRate as (reward * WAD) / duration to maintain precision
     */
    function notifyRewardAmount(
        address rewardToken,
        uint256 reward,
        uint256 newRewardsDuration
    ) external;

    /* @notice Set the duration for rewards distribution
     * @param rewardToken The address of the reward token
     * @param _rewardsDuration The new duration for rewards
     */
    function setRewardsDuration(
        address rewardToken,
        uint256 _rewardsDuration
    ) external;

    /* @notice Removes a reward token from the list of reward tokens
     * @dev Can only be called by governor
     * @dev Can only be called after reward period is complete
     * @dev Can only be called if remaining balance is below dust threshold
     * @param rewardToken The address of the reward token to remove
     */
    function removeRewardToken(address rewardToken) external;

    // Events

    /* @notice Emitted when a new reward is added
     * @param rewardToken The address of the reward token
     * @param reward The amount of reward added
     */
    event RewardAdded(address indexed rewardToken, uint256 reward);

    /* @notice Emitted when tokens are staked
     * @param staker The address that provided the tokens for staking
     * @param receiver The address whose staking balance was updated
     * @param amount The amount of tokens added to the staking position
     */
    event Staked(
        address indexed staker,
        address indexed receiver,
        uint256 amount
    );

    /* @notice Emitted when tokens are unstaked
     * @param staker The address whose tokens were unstaked
     * @param receiver The address receiving the unstaked tokens
     * @param amount The amount of tokens unstaked
     */
    event Unstaked(
        address indexed staker,
        address indexed receiver,
        uint256 amount
    );

    /* @notice Emitted when tokens are withdrawn
     * @param user The address of the user that withdrew
     * @param amount The amount of tokens withdrawn
     */
    event Withdrawn(address indexed user, uint256 amount);

    /* @notice Emitted when rewards are paid out
     * @param user The address of the user receiving the reward
     * @param rewardToken The address of the reward token
     * @param reward The amount of reward paid
     */
    event RewardPaid(
        address indexed user,
        address indexed rewardToken,
        uint256 reward
    );

    /* @notice Emitted when the rewards duration is updated
     * @param rewardToken The address of the reward token
     * @param newDuration The new duration for rewards
     */
    event RewardsDurationUpdated(
        address indexed rewardToken,
        uint256 newDuration
    );

    /* @notice Emitted when a new reward token is added
     * @param rewardToken The address of the new reward token
     * @param rewardsDuration The duration for the new reward token
     */
    event RewardTokenAdded(address rewardToken, uint256 rewardsDuration);

    /* @notice Emitted when a reward token is removed
     * @param rewardToken The address of the reward token
     */
    event RewardTokenRemoved(address rewardToken);

    /* @notice Claims rewards for a specific account
     * @param account The address to claim rewards for
     */
    function getRewardFor(address account) external;

    /* @notice Claims rewards for a specific account and specific reward token
     * @param account The address to claim rewards for
     * @param rewardToken The address of the reward token to claim
     */
    function getRewardFor(address account, address rewardToken) external;
}

// src/types/ArkTypes.sol

/**
 * @title ArkParams
 * @notice Constructor parameters for the Ark contract
 *
 *  @dev This struct is used to initialize an Ark contract with all necessary parameters
 */
struct ArkParams {
    /**
     * @notice The name of the Ark
     * @dev This should be a unique, human-readable identifier for the Ark
     */
    string name;
    /**
     * @notice Additional details about the Ark
     * @dev This can be used to store additional information about the Ark
     */
    string details;
    /**
     * @notice The address of the access manager contract
     * @dev This contract manages roles and permissions for the Ark
     */
    address accessManager;
    /**
     * @notice The address of the configuration manager contract
     * @dev This contract stores global configuration parameters
     */
    address configurationManager;
    /**
     * @notice The address of the ERC20 token managed by this Ark
     * @dev This is the underlying asset that the Ark will handle
     */
    address asset;
    /**
     * @notice The maximum amount of tokens that can be deposited into the Ark
     * @dev This cap helps to manage risk and exposure
     */
    uint256 depositCap;
    /**
     * @notice The maximum amount of tokens that can be moved from this Ark in a single transaction
     * @dev This limit helps to prevent large, sudden outflows
     */
    uint256 maxRebalanceOutflow;
    /**
     * @notice The maximum amount of tokens that can be moved to this Ark in a single transaction
     * @dev This limit helps to prevent large, sudden inflows
     */
    uint256 maxRebalanceInflow;
    /**
     * @notice Whether the Ark requires Keepr data to be passed in with rebalance transactions
     * @dev This flag is used to determine whether Keepr data is required for rebalance transactions
     */
    bool requiresKeeperData;
    /**
     * @notice The maximum percentage of Total Value Locked (TVL) that can be deposited into this Ark
     * @dev This value is represented as a percentage with 18 decimal places (1e18 = 100%)
     *      For example, 0.5e18 represents 50% of TVL
     */
    Percentage maxDepositPercentageOfTVL;
}

/**
 * @title ArkConfig
 * @notice Configuration of the Ark contract
 * @dev This struct stores the current configuration of an Ark, which can be updated during its lifecycle
 */
struct ArkConfig {
    /**
     * @notice The address of the commander (typically a FleetCommander contract)
     * @dev The commander has special permissions to manage the Ark
     */
    address commander;
    /**
     * @notice The address of the associated Raft contract
     * @dev The Raft contract handles reward distribution and other protocol-wide functions
     */
    address raft;
    /**
     * @notice The ERC20 token interface for the asset managed by this Ark
     * @dev This allows direct interaction with the token contract
     */
    IERC20 asset;
    /**
     * @notice The current maximum amount of tokens that can be deposited into the Ark
     * @dev This can be adjusted by the commander to manage capacity
     */
    uint256 depositCap;
    /**
     * @notice The current maximum amount of tokens that can be moved from this Ark in a single transaction
     * @dev This can be adjusted to manage liquidity and risk
     */
    uint256 maxRebalanceOutflow;
    /**
     * @notice The current maximum amount of tokens that can be moved to this Ark in a single transaction
     * @dev This can be adjusted to manage inflows and capacity
     */
    uint256 maxRebalanceInflow;
    /**
     * @notice The name of the Ark
     * @dev This is typically set at initialization and not changed
     */
    string name;
    /**
     * @notice Additional details about the Ark
     * @dev This can be used to store additional information about the Ark
     */
    string details;
    /**
     * @notice Whether the Ark requires Keeper data to be passed in with rebalance transactions
     * @dev This flag is used to determine whether Keeper data is required for rebalance transactions
     */
    bool requiresKeeperData;
    /**
     * @notice The maximum percentage of Total Value Locked (TVL) that can be deposited into this Ark
     * @dev This value is represented as a percentage with 18 decimal places (1e18 = 100%)
     *      For example, 0.5e18 represents 50% of TVL
     */
    Percentage maxDepositPercentageOfTVL;
}

// src/interfaces/IConfigurationManager.sol

/**
 * @title IConfigurationManager
 * @notice Interface for the ConfigurationManager contract, which manages system-wide parameters
 * @dev This interface defines the getters and setters for system-wide parameters
 */

interface IConfigurationManager is
    IConfigurationManagerEvents,
    IConfigurationManagerErrors
{
    /**
     * @notice Initialize the configuration with the given parameters
     * @param params The parameters to initialize the configuration with
     * @dev Can only be called by the governor
     */
    function initializeConfiguration(
        ConfigurationManagerParams memory params
    ) external;

    /**
     * @notice Get the address of the Raft contract
     * @return The address of the Raft contract
     * @dev This is where rewards and farmed tokens are sent for processing
     */
    function raft() external view returns (address);

    /**
     * @notice Get the current tip jar address
     * @return The current tip jar address
     * @dev This is the contract that owns tips and is responsible for
     *     dispensing them to claimants
     */
    function tipJar() external view returns (address);

    /**
     * @notice Get the current treasury address
     * @return The current treasury address
     *       @dev This is the contract that owns the treasury and is responsible for
     *      dispensing funds to the protocol's operations
     */
    function treasury() external view returns (address);

    /**
     * @notice Get the address of theHarbor command
     * @return The address of theHarbor command
     * @dev This is the contract that's the registry of all Fleet Commanders
     */
    function harborCommand() external view returns (address);

    /**
     * @notice Get the address of the Fleet Commander Rewards Manager Factory contract
     * @return The address of the Fleet Commander Rewards Manager Factory contract
     */
    function fleetCommanderRewardsManagerFactory()
        external
        view
        returns (address);

    /**
     * @notice Set a new address for the Raft contract
     * @param newRaft The new address for the Raft contract
     * @dev Can only be called by the governor
     */
    function setRaft(address newRaft) external;

    /**
     * @notice Set a new tip ar address
     * @param newTipJar The address of the new tip jar
     * @dev Can only be called by the governor
     */
    function setTipJar(address newTipJar) external;

    /**
     * @notice Set a new treasury address
     * @param newTreasury The address of the new treasury
     * @dev Can only be called by the governor
     */
    function setTreasury(address newTreasury) external;

    /**
     * @notice Set a new harbor command address
     * @param newHarborCommand The address of the new harbor command
     * @dev Can only be called by the governor
     */
    function setHarborCommand(address newHarborCommand) external;

    /**
     * @notice Set a new fleet commander rewards manager factory address
     * @param newFleetCommanderRewardsManagerFactory The address of the new fleet commander rewards manager factory
     * @dev Can only be called by the governor
     */
    function setFleetCommanderRewardsManagerFactory(
        address newFleetCommanderRewardsManagerFactory
    ) external;
}

// src/interfaces/IFleetCommanderRewardsManager.sol

/**
 * @title IFleetCommanderRewardsManager
 * @notice Interface for the FleetStakingRewardsManager contract
 * @dev Extends IStakingRewardsManagerBase with Fleet-specific functionality
 */
interface IFleetCommanderRewardsManager is IStakingRewardsManagerBase {
    /**
     * @notice Returns the address of the FleetCommander contract
     * @return The address of the FleetCommander
     */
    function fleetCommander() external view returns (address);

    /**
     * @notice Thrown when a non-AdmiralsQuarters contract tries
     * to unstake on behalf
     */
    error CallerNotAdmiralsQuarters();

    /**
     * @notice Thrown when AdmiralsQuarters tries to unstake for
     * someone other than msg.sender
     */
    error InvalidUnstakeRecipient();

    /* @notice Thrown when trying to add a staking token as a reward token */
    error CantAddStakingTokenAsReward();
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/access/AccessControl.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(
        bytes32 role,
        address account
    ) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(
        bytes32 role,
        address account
    ) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(
        bytes32 role,
        address callerConfirmation
    ) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(
        bytes32 role,
        address account
    ) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(
        bytes32 role,
        address account
    ) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(
        address from,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(
        address spender,
        uint256 value
    ) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(
        address spender,
        uint256 value,
        bytes calldata data
    ) external returns (bool);
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256))
        private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address owner,
        address spender
    ) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(
        address spender,
        uint256 value
    ) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// src/interfaces/IConfigurationManaged.sol

/**
 * @title IConfigurationManaged
 * @notice Interface for contracts that need to read from the ConfigurationManager
 * @dev This interface defines the standard methods for accessing configuration values
 *      from the ConfigurationManager. It should be implemented by contracts that
 *      need to read these configurations.
 */
interface IConfigurationManaged {
    /**
     * @notice Gets the address of the ConfigurationManager contract
     * @return The address of the ConfigurationManager contract
     */
    function configurationManager()
        external
        view
        returns (IConfigurationManager);

    /**
     * @notice Gets the address of the Raft contract
     * @return The address of the Raft contract
     */
    function raft() external view returns (address);

    /**
     * @notice Gets the address of the TipJar contract
     * @return The address of the TipJar contract
     */
    function tipJar() external view returns (address);

    /**
     * @notice Gets the address of the Treasury contract
     * @return The address of the Treasury contract
     */
    function treasury() external view returns (address);

    /**
     * @notice Gets the address of the HarborCommand contract
     * @return The address of the HarborCommand contract
     */
    function harborCommand() external view returns (address);

    /**
     * @notice Gets the address of the Fleet Commander Rewards Manager Factory contract
     * @return The address of the Fleet Commander Rewards Manager Factory contract
     */
    function fleetCommanderRewardsManagerFactory()
        external
        view
        returns (address);

    error ConfigurationManagerZeroAddress();
}

// node_modules/@summerfi/access-contracts/src/interfaces/IProtocolAccessManager.sol

/**
 * @dev Dynamic roles are roles that are not hardcoded in the contract but are defined by the protocol
 * Members of this enum are treated as prefixes to the role generated using prefix and target contract address
 * e.g generateRole(ContractSpecificRoles.CURATOR_ROLE, address(this)) for FleetCommander, to generate the CURATOR_ROLE
 * for the curator of the FleetCommander contract
 */
enum ContractSpecificRoles {
    CURATOR_ROLE,
    KEEPER_ROLE,
    COMMANDER_ROLE
}

/**
 * @title IProtocolAccessManager
 * @notice Defines system roles and provides role based remote-access control for
 *         contracts that inherit from ProtocolAccessManaged contract
 */
interface IProtocolAccessManager {
    /**
     * @notice Grants the Governor role to a given account
     *
     * @param account The account to which the Governor role will be granted
     */
    function grantGovernorRole(address account) external;

    /**
     * @notice Revokes the Governor role from a given account
     *
     * @param account The account from which the Governor role will be revoked
     */
    function revokeGovernorRole(address account) external;

    /**
     * @notice Grants the Super Keeper role to a given account
     *
     * @param account The account to which the Super Keeper role will be granted
     */
    function grantSuperKeeperRole(address account) external;

    /**
     * @notice Revokes the Super Keeper role from a given account
     *
     * @param account The account from which the Super Keeper role will be revoked
     */
    function revokeSuperKeeperRole(address account) external;

    /**
     * @dev Generates a unique role identifier based on the role name and target contract address
     * @param roleName The name of the role (from ContractSpecificRoles enum)
     * @param roleTargetContract The address of the contract the role is for
     * @return bytes32 The generated role identifier
     * @custom:internal-logic
     * - Combines the roleName and roleTargetContract using abi.encodePacked
     * - Applies keccak256 hash function to generate a unique bytes32 identifier
     * @custom:effects
     * - Does not modify any state, pure function
     * @custom:security-considerations
     * - Ensures unique role identifiers for different contracts
     * - Relies on the uniqueness of contract addresses and role names
     */
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) external pure returns (bytes32);

    /**
     * @notice Grants a contract specific role to a given account
     * @param roleName The name of the role to grant
     * @param roleTargetContract The address of the contract to grant the role for
     * @param account The account to which the role will be granted
     */
    function grantContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address account
    ) external;

    /**
     * @notice Revokes a contract specific role from a given account
     * @param roleName The name of the role to revoke
     * @param roleTargetContract The address of the contract to revoke the role for
     * @param account The account from which the role will be revoked
     */
    function revokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address account
    ) external;

    /**
     * @notice Grants the Curator role to a given account
     * @param fleetCommanderAddress The address of the fleet commander to grant the role for
     * @param account The account to which the role will be granted
     */
    function grantCuratorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Revokes the Curator role from a given account
     * @param fleetCommanderAddress The address of the fleet commander to revoke the role for
     * @param account The account from which the role will be revoked
     */
    function revokeCuratorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Grants the Keeper role to a given account
     * @param fleetCommanderAddress The address of the fleet commander to grant the role for
     * @param account The account to which the role will be granted
     */
    function grantKeeperRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Revokes the Keeper role from a given account
     * @param fleetCommanderAddress The address of the fleet commander to revoke the role for
     * @param account The account from which the role will be revoked
     */
    function revokeKeeperRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Grants the Commander role for a specific Ark
     * @param arkAddress Address of the Ark contract
     * @param account Address to grant the Commander role to
     */
    function grantCommanderRole(address arkAddress, address account) external;

    /**
     * @notice Revokes the Commander role for a specific Ark
     * @param arkAddress Address of the Ark contract
     * @param account Address to revoke the Commander role from
     */
    function revokeCommanderRole(address arkAddress, address account) external;

    /**
     * @notice Revokes a contract specific role from the caller
     * @param roleName The name of the role to revoke
     * @param roleTargetContract The address of the contract to revoke the role for
     */
    function selfRevokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) external;

    /**
     * @notice Grants the Guardian role to a given account
     *
     * @param account The account to which the Guardian role will be granted
     */
    function grantGuardianRole(address account) external;

    /**
     * @notice Revokes the Guardian role from a given account
     *
     * @param account The account from which the Guardian role will be revoked
     */
    function revokeGuardianRole(address account) external;

    /**
     * @notice Grants the Decay Controller role to a given account
     * @param account The account to which the Decay Controller role will be granted
     */
    function grantDecayControllerRole(address account) external;

    /**
     * @notice Revokes the Decay Controller role from a given account
     * @param account The account from which the Decay Controller role will be revoked
     */
    function revokeDecayControllerRole(address account) external;

    /**
     * @notice Grants the ADMIRALS_QUARTERS_ROLE to an address
     * @param account The address to grant the role to
     */
    function grantAdmiralsQuartersRole(address account) external;

    /**
     * @notice Revokes the ADMIRALS_QUARTERS_ROLE from an address
     * @param account The address to revoke the role from
     */
    function revokeAdmiralsQuartersRole(address account) external;

    /*//////////////////////////////////////////////////////////////
                            ROLE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for the Governor role
    function GOVERNOR_ROLE() external pure returns (bytes32);

    /// @notice Role identifier for the Guardian role
    function GUARDIAN_ROLE() external pure returns (bytes32);

    /// @notice Role identifier for the Super Keeper role
    function SUPER_KEEPER_ROLE() external pure returns (bytes32);

    /// @notice Role identifier for the Decay Controller role
    function DECAY_CONTROLLER_ROLE() external pure returns (bytes32);

    /// @notice Role identifier for the Admirals Quarters role
    function ADMIRALS_QUARTERS_ROLE() external pure returns (bytes32);

    /// @notice Role identifier for the Foundation, responsible for managing vesting wallets and related operations
    function FOUNDATION_ROLE() external pure returns (bytes32);

    /**
     * @notice Checks if an account has a specific role
     * @param role The role identifier to check
     * @param account The account to check the role for
     * @return bool True if the account has the role, false otherwise
     */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a guardian's expiration is set
     * @param account The address of the guardian
     * @param expiration The timestamp until which the guardian powers are valid
     */
    event GuardianExpirationSet(address indexed account, uint256 expiration);

    /*//////////////////////////////////////////////////////////////
                            GUARDIAN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if an account is an active guardian (has role and not expired)
     * @param account Address to check
     * @return bool True if account is an active guardian
     */
    function isActiveGuardian(address account) external view returns (bool);

    /**
     * @notice Sets the expiration timestamp for a guardian
     * @param account Guardian address
     * @param expiration Timestamp when guardian powers expire
     */
    function setGuardianExpiration(
        address account,
        uint256 expiration
    ) external;

    /**
     * @notice Gets the expiration timestamp for a guardian
     * @param account Guardian address
     * @return uint256 Timestamp when guardian powers expire
     */
    function guardianExpirations(
        address account
    ) external view returns (uint256);

    /**
     * @notice Gets the expiration timestamp for a guardian
     * @param account Guardian address
     * @return expiration Timestamp when guardian powers expire
     */
    function getGuardianExpiration(
        address account
    ) external view returns (uint256 expiration);

    /**
     * @notice Emitted when an invalid guardian expiry period is set
     * @param expiryPeriod The expiry period that was set
     * @param minExpiryPeriod The minimum allowed expiry period
     * @param maxExpiryPeriod The maximum allowed expiry period
     */
    error InvalidGuardianExpiryPeriod(
        uint256 expiryPeriod,
        uint256 minExpiryPeriod,
        uint256 maxExpiryPeriod
    );

    /**
     * @notice Grants the Foundation role to a given account. The Foundation is responsible for
     * managing vesting wallets and related operations.
     * @param account The account to which the Foundation role will be granted
     */
    function grantFoundationRole(address account) external;

    /**
     * @notice Revokes the Foundation role from a given account
     * @param account The account from which the Foundation role will be revoked
     */
    function revokeFoundationRole(address account) external;
}

// node_modules/@summerfi/access-contracts/src/contracts/LimitedAccessControl.sol

/**
 * @title LimitedAccessControl
 * @dev This contract extends OpenZeppelin's AccessControl, disabling direct role granting and revoking.
 * It's designed to be used as a base contract for more specific access control implementations.
 * @dev This contract overrides the grantRole and revokeRole functions from AccessControl to disable direct role
 * granting and revoking.
 * @dev It doesn't override the renounceRole function, so it can be used to renounce roles for compromised accounts.
 */
abstract contract LimitedAccessControl is AccessControl, IAccessControlErrors {
    /**
     * @dev Overrides the grantRole function from AccessControl to disable direct role granting.
     * @notice This function always reverts with a DirectGrantIsDisabled error.
     */
    function grantRole(bytes32, address) public view override {
        revert DirectGrantIsDisabled(msg.sender);
    }

    /**
     * @dev Overrides the revokeRole function from AccessControl to disable direct role revoking.
     * @notice This function always reverts with a DirectRevokeIsDisabled error.
     */
    function revokeRole(bytes32, address) public view override {
        revert DirectRevokeIsDisabled(msg.sender);
    }
}

// src/interfaces/IArkConfigProvider.sol

/**
 * @title IArkConfigProvider
 * @notice Interface for configuration of Ark contracts
 * @dev Inherits from IArkAccessManaged for access control and IArkConfigProviderEvents for event definitions
 */
interface IArkConfigProvider is
    IArkAccessManaged,
    IArkConfigProviderErrors,
    IArkConfigProviderEvents
{
    /**
     * @notice Retrieves the current fleet config
     */
    function getConfig() external view returns (ArkConfig memory);

    /**
     * @dev Returns the name of the Ark.
     * @return The name of the Ark as a string.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the details of the Ark
     * @return The details of the Ark as a string
     */
    function details() external view returns (string memory);

    /**
     * @notice Returns the deposit cap for this Ark
     * @return The maximum amount of tokens that can be deposited into the Ark
     */
    function depositCap() external view returns (uint256);

    /**
     * @notice Returns the maximum percentage of TVL that can be deposited into the Ark
     * @return The maximum percentage of TVL that can be deposited into the Ark
     */
    function maxDepositPercentageOfTVL() external view returns (Percentage);

    /**
     * @notice Returns the maximum amount that can be moved to this Ark in one rebalance
     * @return maximum amount that can be moved to this Ark in one rebalance
     */
    function maxRebalanceInflow() external view returns (uint256);

    /**
     * @notice Returns the maximum amount that can be moved from this Ark in one rebalance
     * @return maximum amount that can be moved from this Ark in one rebalance
     */
    function maxRebalanceOutflow() external view returns (uint256);

    /**
     * @notice Returns whether the Ark requires keeper data to board/disembark
     * @return true if the Ark requires keeper data, false otherwise
     */
    function requiresKeeperData() external view returns (bool);

    /**
     * @notice Returns the ERC20 token managed by this Ark
     * @return The IERC20 interface of the managed token
     */
    function asset() external view returns (IERC20);

    /**
     * @notice Returns the address of the Fleet commander managing the ark
     * @return address Address of Fleet commander managing the ark if a Commander is assigned, address(0) otherwise
     */
    function commander() external view returns (address);

    /**
     * @notice Sets a new maximum allocation for the Ark
     * @param newDepositCap The new maximum allocation amount
     */
    function setDepositCap(uint256 newDepositCap) external;

    /**
     * @notice Sets a new maximum deposit percentage of TVL for the Ark
     * @param newMaxDepositPercentageOfTVL The new maximum deposit percentage of TVL
     */
    function setMaxDepositPercentageOfTVL(
        Percentage newMaxDepositPercentageOfTVL
    ) external;

    /**
     * @notice Sets a new maximum amount that can be moved from the Ark in one rebalance
     * @param newMaxRebalanceOutflow The new maximum amount that can be moved from the Ark
     */
    function setMaxRebalanceOutflow(uint256 newMaxRebalanceOutflow) external;

    /**
     * @notice Sets a new maximum amount that can be moved to the Ark in one rebalance
     * @param newMaxRebalanceInflow The new maximum amount that can be moved to the Ark
     */
    function setMaxRebalanceInflow(uint256 newMaxRebalanceInflow) external;

    /**
     * @notice Registers the Fleet commander for the Ark
     * @dev This function is used to register the Fleet commander for the Ark
     * it's called by the FleetCommander when ark is added to the fleet
     */
    function registerFleetCommander() external;

    /**
     * @notice Unregisters the Fleet commander for the Ark
     * @dev This function is used to unregister the Fleet commander for the Ark
     * it's called by the FleetCommander when ark is removed from the fleet
     * all balance checks are done within the FleetCommander
     */
    function unregisterFleetCommander() external;
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(
        address spender,
        uint256 currentAllowance,
        uint256 requestedDecrease
    );

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeCall(token.transferFrom, (from, to, value))
        );
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 requestedDecrease
    ) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(
                    spender,
                    currentAllowance,
                    requestedDecrease
                );
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        bytes memory approvalCall = abi.encodeCall(
            token.approve,
            (spender, value)
        );

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(
                token,
                abi.encodeCall(token.approve, (spender, 0))
            );
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(
        IERC1363 token,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(
        IERC1363 token,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(
                gas(),
                token,
                0,
                add(data, 0x20),
                mload(data),
                0,
                0x20
            )
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (
            returnSize == 0 ? address(token).code.length == 0 : returnValue != 1
        ) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(
        IERC20 token,
        bytes memory data
    ) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(
                gas(),
                token,
                0,
                add(data, 0x20),
                mload(data),
                0,
                0x20
            )
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return
            success &&
            (
                returnSize == 0
                    ? address(token).code.length > 0
                    : returnValue == 1
            );
    }
}

// node_modules/@summerfi/access-contracts/src/contracts/ProtocolAccessManager.sol

/**
 * @title ProtocolAccessManager
 * @notice This contract is the central authority for access control within the protocol.
 * It defines and manages various roles that govern different aspects of the system.
 *
 * @dev This contract extends LimitedAccessControl, which restricts direct role management.
 * Roles are typically assigned during deployment or through governance proposals.
 *
 * The contract defines four main roles:
 * 1. GOVERNOR_ROLE: System-wide administrators
 * 2. KEEPER_ROLE: Routine maintenance operators
 * 3. SUPER_KEEPER_ROLE: Advanced maintenance operators
 * 4. COMMANDER_ROLE: Managers of specific protocol components (Arks)
 * 5. ADMIRALS_QUARTERS_ROLE: Specific role for admirals quarters bundler contract
 * Role Hierarchy and Management:
 * - The GOVERNOR_ROLE is at the top of the hierarchy and can manage all other roles.
 * - Other roles cannot manage roles directly due to LimitedAccessControl restrictions.
 * - Role assignments are typically done through governance proposals or during initial setup.
 *
 * Usage in the System:
 * - Other contracts in the system inherit from ProtocolAccessManaged, which checks permissions
 *   against this ProtocolAccessManager.
 * - Critical functions in various contracts are protected by role-based modifiers
 *   (e.g., onlyGovernor, onlyKeeper, etc.) which query this contract for permissions.
 *
 * Security Considerations:
 * - The GOVERNOR_ROLE has significant power and should be managed carefully, potentially
 *   through a multi-sig wallet or governance contract.
 * - The SUPER_KEEPER_ROLE has elevated privileges and should be assigned judiciously.
 * - The COMMANDER_ROLE is not directly manageable through this contract but is used
 *   in other parts of the system for specific access control.
 */
contract ProtocolAccessManager is IProtocolAccessManager, LimitedAccessControl {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for protocol governors - highest privilege level with admin capabilities
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Role identifier for super keepers who can globally perform fleet maintanence roles
    bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");

    /**
     * @notice Role identifier for protocol guardians
     * @dev Guardians have emergency powers across multiple protocol components:
     * - Can pause/unpause Fleet operations for security
     * - Can pause/unpause TipJar operations
     * - Can cancel governance proposals on SummerGovernor even if they don't meet normal cancellation requirements
     * - Can cancel TipJar proposals
     *
     * The guardian role serves as an emergency backstop to protect the protocol, but with less
     * privilege than governors.
     */
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /**
     * @notice Role identifier for decay controller
     * @dev This role allows the decay controller to manage the decay of user voting power
     */
    bytes32 public constant DECAY_CONTROLLER_ROLE =
        keccak256("DECAY_CONTROLLER_ROLE");

    /**
     * @notice Role identifier for admirals quarters bundler contract
     * @dev This role allows Admirals Quarters to unstake and withdraw assets from fleets, on behalf of users
     * @dev Withdrawn tokens go straight to users wallet, lowering the risk of manipulation if the role is compromised
     */
    bytes32 public constant ADMIRALS_QUARTERS_ROLE =
        keccak256("ADMIRALS_QUARTERS_ROLE");

    /// @notice Minimum allowed guardian expiration period (7 days)
    uint256 public constant MIN_GUARDIAN_EXPIRY = 7 days;

    /// @notice Maximum allowed guardian expiration period (180 days)
    uint256 public constant MAX_GUARDIAN_EXPIRY = 180 days;

    /// @notice Role identifier for the Foundation which manages vesting wallets and related operations
    bytes32 public constant FOUNDATION_ROLE = keccak256("FOUNDATION_ROLE");

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ProtocolAccessManager contract
     * @param governor Address of the initial governor
     * @dev Grants the governor address the GOVERNOR_ROLE
     */
    constructor(address governor) {
        _grantRole(GOVERNOR_ROLE, governor);
    }

    /**
     * @dev Modifier to check that the caller has the Governor role
     */
    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if the contract supports a given interface
     * @dev Overrides the supportsInterface function from AccessControl
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract supports the interface, false otherwise
     *
     * This function supports:
     * - IProtocolAccessManager interface
     * - All interfaces supported by the parent AccessControl contract
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IProtocolAccessManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantGovernorRole(address account) external onlyGovernor {
        _grantRole(GOVERNOR_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeGovernorRole(address account) external onlyGovernor {
        _revokeRole(GOVERNOR_ROLE, account);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    function grantSuperKeeperRole(address account) external onlyGovernor {
        _grantRole(SUPER_KEEPER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantGuardianRole(address account) external onlyGovernor {
        _grantRole(GUARDIAN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeGuardianRole(address account) external onlyGovernor {
        _revokeRole(GUARDIAN_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeSuperKeeperRole(address account) external onlyGovernor {
        _revokeRole(SUPER_KEEPER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address roleOwner
    ) public onlyGovernor {
        bytes32 role = generateRole(roleName, roleTargetContract);
        _grantRole(role, roleOwner);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract,
        address roleOwner
    ) public onlyGovernor {
        bytes32 role = generateRole(roleName, roleTargetContract);
        _revokeRole(role, roleOwner);
    }

    /// @inheritdoc IProtocolAccessManager
    function grantCuratorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeCuratorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function grantKeeperRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeKeeperRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function grantCommanderRole(
        address arkAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            arkAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeCommanderRole(
        address arkAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            arkAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManager
    function grantDecayControllerRole(address account) public onlyGovernor {
        _grantRole(DECAY_CONTROLLER_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeDecayControllerRole(address account) public onlyGovernor {
        _revokeRole(DECAY_CONTROLLER_ROLE, account);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProtocolAccessManager
    function selfRevokeContractSpecificRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public {
        bytes32 role = generateRole(roleName, roleTargetContract);
        if (!hasRole(role, msg.sender)) {
            revert CallerIsNotContractSpecificRole(msg.sender, role);
        }
        _revokeRole(role, msg.sender);
    }

    /// @inheritdoc IProtocolAccessManager
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(roleName, roleTargetContract));
    }

    /// @inheritdoc IProtocolAccessManager
    function grantAdmiralsQuartersRole(
        address account
    ) external onlyRole(GOVERNOR_ROLE) {
        _grantRole(ADMIRALS_QUARTERS_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeAdmiralsQuartersRole(
        address account
    ) external onlyRole(GOVERNOR_ROLE) {
        _revokeRole(ADMIRALS_QUARTERS_ROLE, account);
    }

    mapping(address guardian => uint256 expirationTimestamp)
        public guardianExpirations;

    /**
     * @notice Checks if an account is an active guardian (has role and not expired)
     * @param account Address to check
     * @return bool True if account is an active guardian
     */
    function isActiveGuardian(address account) public view returns (bool) {
        return
            hasRole(GUARDIAN_ROLE, account) &&
            guardianExpirations[account] > block.timestamp;
    }

    /**
     * @notice Sets the expiration timestamp for a guardian
     * @param account Guardian address
     * @param expiration Timestamp when guardian powers expire
     * @dev The expiration period (time from now until expiration) must be between MIN_GUARDIAN_EXPIRY and MAX_GUARDIAN_EXPIRY
     * This ensures guardians can't be immediately removed (protecting against malicious proposals) while still
     * allowing for their eventual phase-out (protecting against malicious guardians)
     */
    function setGuardianExpiration(
        address account,
        uint256 expiration
    ) external onlyRole(GOVERNOR_ROLE) {
        if (!hasRole(GUARDIAN_ROLE, account)) {
            revert CallerIsNotGuardian(account);
        }

        uint256 expiryPeriod = expiration - block.timestamp;
        if (
            expiryPeriod < MIN_GUARDIAN_EXPIRY ||
            expiryPeriod > MAX_GUARDIAN_EXPIRY
        ) {
            revert InvalidGuardianExpiryPeriod(
                expiryPeriod,
                MIN_GUARDIAN_EXPIRY,
                MAX_GUARDIAN_EXPIRY
            );
        }

        guardianExpirations[account] = expiration;
        emit GuardianExpirationSet(account, expiration);
    }

    /**
     * @inheritdoc IProtocolAccessManager
     */
    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        virtual
        override(IProtocolAccessManager, AccessControl)
        returns (bool)
    {
        return super.hasRole(role, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function getGuardianExpiration(
        address account
    ) external view returns (uint256 expiration) {
        if (!hasRole(GUARDIAN_ROLE, account)) {
            revert CallerIsNotGuardian(account);
        }
        return guardianExpirations[account];
    }

    /// @inheritdoc IProtocolAccessManager
    function grantFoundationRole(address account) external onlyGovernor {
        _grantRole(FOUNDATION_ROLE, account);
    }

    /// @inheritdoc IProtocolAccessManager
    function revokeFoundationRole(address account) external onlyGovernor {
        _revokeRole(FOUNDATION_ROLE, account);
    }
}

// node_modules/@summerfi/access-contracts/src/contracts/ProtocolAccessManaged.sol

/**
 * @title ProtocolAccessManaged
 * @notice This contract provides role-based access control functionality for protocol contracts
 * by interfacing with a central ProtocolAccessManager.
 *
 * @dev This contract is meant to be inherited by other protocol contracts that need
 * role-based access control. It provides modifiers and utilities to check various roles.
 *
 * The contract supports several key roles through modifiers:
 * 1. GOVERNOR_ROLE: System-wide administrators
 * 2. KEEPER_ROLE: Routine maintenance operators (contract-specific)
 * 3. SUPER_KEEPER_ROLE: Advanced maintenance operators (global)
 * 4. CURATOR_ROLE: Fleet-specific managers
 * 5. GUARDIAN_ROLE: Emergency response operators
 * 6. DECAY_CONTROLLER_ROLE: Specific role for decay management
 * 7. ADMIRALS_QUARTERS_ROLE: Specific role for admirals quarters bundler contract
 *
 * Usage:
 * - Inherit from this contract to gain access to role-checking modifiers
 * - Use modifiers like onlyGovernor, onlyKeeper, etc. to protect functions
 * - Access the internal _accessManager to perform custom role checks
 *
 * Security Considerations:
 * - The contract validates the access manager address during construction
 * - All role checks are performed against the immutable access manager instance
 * - Contract-specific roles are generated using the contract's address to prevent conflicts
 */
contract ProtocolAccessManaged is IAccessControlErrors, Context {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for protocol governors - highest privilege level with admin capabilities
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Role identifier for super keepers who can globally perform fleet maintanence roles
    bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");

    /**
     * @notice Role identifier for protocol guardians
     * @dev Guardians have emergency powers across multiple protocol components:
     * - Can pause/unpause Fleet operations for security
     * - Can pause/unpause TipJar operations
     * - Can cancel governance proposals on SummerGovernor even if they don't meet normal cancellation requirements
     * - Can cancel TipJar proposals
     *
     * The guardian role serves as an emergency backstop to protect the protocol, but with less
     * privilege than governors.
     */
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /**
     * @notice Role identifier for decay controller
     * @dev This role allows the decay controller to manage the decay of user voting power
     */
    bytes32 public constant DECAY_CONTROLLER_ROLE =
        keccak256("DECAY_CONTROLLER_ROLE");

    /**
     * @notice Role identifier for admirals quarters bundler contract
     * @dev This role allows Admirals Quarters to unstake and withdraw assets from fleets, on behalf of users
     * @dev Withdrawn tokens go straight to users wallet, lowering the risk of manipulation if the role is compromised
     */
    bytes32 public constant ADMIRALS_QUARTERS_ROLE =
        keccak256("ADMIRALS_QUARTERS_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The ProtocolAccessManager instance used for access control
    ProtocolAccessManager internal immutable _accessManager;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the ProtocolAccessManaged contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @dev Validates the provided accessManager address and initializes the _accessManager
     */
    constructor(address accessManager) {
        if (accessManager == address(0)) {
            revert InvalidAccessManagerAddress(address(0));
        }

        if (
            !IERC165(accessManager).supportsInterface(
                type(IProtocolAccessManager).interfaceId
            )
        ) {
            revert InvalidAccessManagerAddress(accessManager);
        }

        _accessManager = ProtocolAccessManager(accessManager);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to restrict access to governors only
     *
     * @dev Modifier to check that the caller has the Governor role
     * @custom:internal-logic
     * - Checks if the caller has the GOVERNOR_ROLE in the access manager
     * @custom:effects
     * - Reverts if the caller doesn't have the GOVERNOR_ROLE
     * - Allows the function to proceed if the caller has the role
     * @custom:security-considerations
     * - Ensures that only authorized governors can access critical functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlyGovernor() {
        if (!_accessManager.hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to keepers only
     * @dev Modifier to check that the caller has the Keeper role
     * @custom:internal-logic
     * - Checks if the caller has either the contract-specific KEEPER_ROLE or the SUPER_KEEPER_ROLE
     * @custom:effects
     * - Reverts if the caller doesn't have either of the required roles
     * - Allows the function to proceed if the caller has one of the roles
     * @custom:security-considerations
     * - Ensures that only authorized keepers can access maintenance functions
     * - Allows for both contract-specific and super keepers
     * @custom:gas-considerations
     * - Performs two role checks, which may impact gas usage
     */
    modifier onlyKeeper() {
        if (
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.KEEPER_ROLE, address(this)),
                msg.sender
            ) && !_accessManager.hasRole(SUPER_KEEPER_ROLE, msg.sender)
        ) {
            revert CallerIsNotKeeper(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to super keepers only
     * @dev Modifier to check that the caller has the Super Keeper role
     * @custom:internal-logic
     * - Checks if the caller has the SUPER_KEEPER_ROLE in the access manager
     * @custom:effects
     * - Reverts if the caller doesn't have the SUPER_KEEPER_ROLE
     * - Allows the function to proceed if the caller has the role
     * @custom:security-considerations
     * - Ensures that only authorized super keepers can access advanced maintenance functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlySuperKeeper() {
        if (!_accessManager.hasRole(SUPER_KEEPER_ROLE, msg.sender)) {
            revert CallerIsNotSuperKeeper(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to curators only
     * @param fleetAddress The address of the fleet to check the curator role for
     * @dev Checks if the caller has the contract-specific CURATOR_ROLE
     */
    modifier onlyCurator(address fleetAddress) {
        if (
            fleetAddress == address(0) ||
            !_accessManager.hasRole(
                generateRole(ContractSpecificRoles.CURATOR_ROLE, fleetAddress),
                msg.sender
            )
        ) {
            revert CallerIsNotCurator(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to guardians only
     * @dev Modifier to check that the caller has the Guardian role
     * @custom:internal-logic
     * - Checks if the caller has the GUARDIAN_ROLE in the access manager
     * @custom:effects
     * - Reverts if the caller doesn't have the GUARDIAN_ROLE
     * - Allows the function to proceed if the caller has the role
     * @custom:security-considerations
     * - Ensures that only authorized guardians can access emergency functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlyGuardian() {
        if (!_accessManager.hasRole(GUARDIAN_ROLE, msg.sender)) {
            revert CallerIsNotGuardian(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to either guardians or governors
     * @dev Modifier to check that the caller has either the Guardian or Governor role
     * @custom:internal-logic
     * - Checks if the caller has either the GUARDIAN_ROLE or the GOVERNOR_ROLE
     * @custom:effects
     * - Reverts if the caller doesn't have either of the required roles
     * - Allows the function to proceed if the caller has one of the roles
     * @custom:security-considerations
     * - Ensures that only authorized guardians or governors can access certain functions
     * - Provides flexibility for functions that can be accessed by either role
     * @custom:gas-considerations
     * - Performs two role checks, which may impact gas usage
     */
    modifier onlyGuardianOrGovernor() {
        if (
            !_accessManager.hasRole(GUARDIAN_ROLE, msg.sender) &&
            !_accessManager.hasRole(GOVERNOR_ROLE, msg.sender)
        ) {
            revert CallerIsNotGuardianOrGovernor(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to decay controllers only
     */
    modifier onlyDecayController() {
        if (!_accessManager.hasRole(DECAY_CONTROLLER_ROLE, msg.sender)) {
            revert CallerIsNotDecayController(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to foundation only
     * @dev Modifier to check that the caller has the Foundation role
     * @custom:security-considerations
     * - Ensures that only the Foundation can access vesting and related functions
     * - Relies on the correct setup of the access manager
     */
    modifier onlyFoundation() {
        if (
            !_accessManager.hasRole(
                _accessManager.FOUNDATION_ROLE(),
                msg.sender
            )
        ) {
            revert CallerIsNotFoundation(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a role identifier for a specific contract and role
     * @param roleName The name of the role
     * @param roleTargetContract The address of the contract the role is for
     * @return The generated role identifier
     * @dev This function is used to create unique role identifiers for contract-specific roles
     */
    function generateRole(
        ContractSpecificRoles roleName,
        address roleTargetContract
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(roleName, roleTargetContract));
    }

    /**
     * @notice Checks if an account has the Admirals Quarters role
     * @param account The address to check
     * @return bool True if the account has the Admirals Quarters role
     */
    function hasAdmiralsQuartersRole(
        address account
    ) public view returns (bool) {
        return _accessManager.hasRole(ADMIRALS_QUARTERS_ROLE, account);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Helper function to check if an address has the Governor role
     * @param account The address to check
     * @return bool True if the address has the Governor role
     */
    function _isGovernor(address account) internal view returns (bool) {
        return _accessManager.hasRole(GOVERNOR_ROLE, account);
    }

    function _isDecayController(address account) internal view returns (bool) {
        return _accessManager.hasRole(DECAY_CONTROLLER_ROLE, account);
    }

    /**
     * @notice Helper function to check if an address has the Foundation role
     * @param account The address to check
     * @return bool True if the address has the Foundation role
     */
    function _isFoundation(address account) internal view returns (bool) {
        return
            _accessManager.hasRole(_accessManager.FOUNDATION_ROLE(), account);
    }
}

// src/interfaces/IArk.sol

/**
 * @title IArk
 * @notice Interface for the Ark contract, which manages funds and interacts with Rafts
 * @dev Inherits from IArkAccessManaged for access control and IArkEvents for event definitions
 */
interface IArk is
    IArkAccessManaged,
    IArkEvents,
    IArkErrors,
    IArkConfigProvider
{
    /**
     * @notice Returns the current underlying balance of the Ark
     * @return The total assets in the Ark, in token precision
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Triggers a harvest operation to collect rewards
     * @param additionalData Optional bytes that might be required by a specific protocol to harvest
     * @return rewardTokens The reward token addresses
     * @return rewardAmounts The reward amounts
     */
    function harvest(
        bytes calldata additionalData
    )
        external
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);

    /**
     * @notice Sweeps tokens from the Ark
     * @param tokens The tokens to sweep
     * @return sweptTokens The swept tokens
     * @return sweptAmounts The swept amounts
     */
    function sweep(
        address[] calldata tokens
    )
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);

    /**
     * @notice Deposits (boards) tokens into the Ark
     * @dev This function is called by the Fleet Commander to deposit assets into the Ark.
     *      It transfers tokens from the caller to this contract and then calls the internal _board function.
     * @param amount The amount of assets to board
     * @param boardData Additional data required for boarding, specific to the Ark implementation
     * @custom:security-note This function is only callable by authorized entities
     */
    function board(uint256 amount, bytes calldata boardData) external;

    /**
     * @notice Withdraws (disembarks) tokens from the Ark
     * @param amount The amount of tokens to withdraw
     * @param disembarkData Additional data that might be required by a specific protocol to withdraw funds
     */
    function disembark(uint256 amount, bytes calldata disembarkData) external;

    /**
     * @notice Moves tokens from one ark to another
     * @param amount The amount of tokens to move
     * @param receiver The address of the Ark the funds will be boarded to
     * @param boardData Additional data that might be required by a specific protocol to board funds
     * @param disembarkData Additional data that might be required by a specific protocol to disembark funds
     */
    function move(
        uint256 amount,
        address receiver,
        bytes calldata boardData,
        bytes calldata disembarkData
    ) external;

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @return uint256 The total assets that are withdrawable
     * @dev _withdrawableTotalAssets is an internal function that should be implemented by derived contracts to define
     * specific withdrawability logic
     * @dev the ark is withdrawable if it doesnt require keeper data and _isWithdrawable returns true
     */
    function withdrawableTotalAssets() external view returns (uint256);
}

// src/types/FleetCommanderTypes.sol

/**
 * @notice Configuration parameters for the FleetCommander contract
 */
struct FleetCommanderParams {
    string name;
    string details;
    string symbol;
    address configurationManager;
    address accessManager;
    address asset;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
}

/**
 * @title FleetConfig
 * @notice Configuration parameters for the FleetCommander contract
 * @dev This struct encapsulates the mutable configuration settings of a FleetCommander.
 *      These parameters can be updated during the contract's lifecycle to adjust its behavior.
 */
struct FleetConfig {
    /**
     * @notice The buffer Ark associated with this FleetCommander
     * @dev This Ark is used as a temporary holding area for funds before they are allocated
     *      to other Arks or when they need to be quickly accessed for withdrawals.
     */
    IArk bufferArk;
    /**
     * @notice The minimum balance that should be maintained in the buffer Ark
     * @dev This value is used to ensure there's always a certain amount of funds readily
     *      available for withdrawals or rebalancing operations. It's denominated in the
     *      smallest unit of the underlying asset (e.g., wei for ETH).
     */
    uint256 minimumBufferBalance;
    /**
     * @notice The maximum total value of assets that can be deposited into the FleetCommander
     * @dev This cap helps manage the total assets under management and can be used to
     *      implement controlled growth strategies. It's denominated in the smallest unit
     *      of the underlying asset.
     */
    uint256 depositCap;
    /**
     * @notice The maximum number of rebalance operations in a single rebalance
     */
    uint256 maxRebalanceOperations;
    /**
     * @notice The address of the staking rewards contract
     */
    address stakingRewardsManager;
}

/**
 * @notice Data structure for the rebalance event
 * @param fromArk The address of the Ark from which assets are moved
 * @param toArk The address of the Ark to which assets are moved
 * @param amount The amount of assets being moved
 * @param boardData The data to be passed to the `board` function of the `toArk`
 * @param disembarkData The data to be passed to the `disembark` function of the `fromArk`
 * @dev if the `boardData` or `disembarkData` is not needed, it should be an empty byte array
 */
struct RebalanceData {
    address fromArk;
    address toArk;
    uint256 amount;
    bytes boardData;
    bytes disembarkData;
}

/**
 * @title ArkData
 * @dev Struct to store information about an Ark.
 * This struct holds the address of the Ark and the total assets it holds.
 * @dev used in the caching mechanism for the FleetCommander
 */
struct ArkData {
    /// @notice The address of the Ark.
    address arkAddress;
    /// @notice The total assets held by the Ark.
    uint256 totalAssets;
}

// src/events/IFleetCommanderEvents.sol

interface IFleetCommanderEvents {
    /* EVENTS */
    /**
     * @notice Emitted when a rebalance operation is completed
     * @param keeper The address of the keeper who initiated the rebalance
     * @param rebalances An array of RebalanceData structs detailing the rebalance operations
     */
    event Rebalanced(address indexed keeper, RebalanceData[] rebalances);

    /**
     * @notice Emitted when queued funds are committed
     * @param keeper The address of the keeper who committed the funds
     * @param prevBalance The previous balance before committing funds
     * @param newBalance The new balance after committing funds
     */
    event QueuedFundsCommitted(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the funds queue is refilled
     * @param keeper The address of the keeper who initiated the queue refill
     * @param prevBalance The previous balance before refilling
     * @param newBalance The new balance after refilling
     */
    event FundsQueueRefilled(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the minimum balance of the funds queue is updated
     * @param keeper The address of the keeper who updated the minimum balance
     * @param newBalance The new minimum balance
     */
    event MinFundsQueueBalanceUpdated(
        address indexed keeper,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the fee address is updated
     * @param newAddress The new fee address
     */
    event FeeAddressUpdated(address newAddress);

    /**
     * @notice Emitted when the funds buffer balance is updated
     * @param user The address of the user who triggered the update
     * @param prevBalance The previous buffer balance
     * @param newBalance The new buffer balance
     */
    event FundsBufferBalanceUpdated(
        address indexed user,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice Emitted when funds are withdrawn from Arks
     * @param owner The address of the owner who initiated the withdrawal
     * @param receiver The address of the receiver of the withdrawn funds
     * @param totalWithdrawn The total amount of funds withdrawn
     */
    event FleetCommanderWithdrawnFromArks(
        address indexed owner,
        address receiver,
        uint256 totalWithdrawn
    );

    /**
     * @notice Emitted when funds are redeemed from Arks
     * @param owner The address of the owner who initiated the redemption
     * @param receiver The address of the receiver of the redeemed funds
     * @param totalRedeemed The total amount of funds redeemed
     */
    event FleetCommanderRedeemedFromArks(
        address indexed owner,
        address receiver,
        uint256 totalRedeemed
    );
    /**
     * @notice Emitted when referee deposits into the FleetCommander
     * @param referee The address of the referee who was referred
     * @param referralCode The referral code of the referrer
     */
    event FleetCommanderReferral(
        address indexed referee,
        bytes indexed referralCode
    );
}

// node_modules/@summerfi/dependencies/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC4626.sol)

/**
 * @dev Implementation of the ERC-4626 "Tokenized Vault Standard" as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 *
 * This extension allows the minting and burning of "shares" (represented using the ERC-20 inheritance) in exchange for
 * underlying "assets" through standardized {deposit}, {mint}, {redeem} and {burn} workflows. This contract extends
 * the ERC-20 standard. Any additional extensions included along it would affect the "shares" token represented by this
 * contract and not the "assets" token which is an independent contract.
 *
 * [CAUTION]
 * ====
 * In empty (or nearly empty) ERC-4626 vaults, deposits are at high risk of being stolen through frontrunning
 * with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
 * attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
 * deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Withdrawals may
 * similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
 * verifying the amount received is as expected, using a wrapper that performs these checks such as
 * https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router].
 *
 * Since v4.9, this implementation introduces configurable virtual assets and shares to help developers mitigate that risk.
 * The `_decimalsOffset()` corresponds to an offset in the decimal representation between the underlying asset's decimals
 * and the vault decimals. This offset also determines the rate of virtual shares to virtual assets in the vault, which
 * itself determines the initial exchange rate. While not fully preventing the attack, analysis shows that the default
 * offset (0) makes it non-profitable even if an attacker is able to capture value from multiple user deposits, as a result
 * of the value being captured by the virtual shares (out of the attacker's donation) matching the attacker's expected gains.
 * With a larger offset, the attack becomes orders of magnitude more expensive than it is profitable. More details about the
 * underlying math can be found xref:erc4626.adoc#inflation-attack[here].
 *
 * The drawback of this approach is that the virtual shares do capture (a very small) part of the value being accrued
 * to the vault. Also, if the vault experiences losses, the users try to exit the vault, the virtual shares and assets
 * will cause the first user to exit to experience reduced losses in detriment to the last users that will experience
 * bigger losses. Developers willing to revert back to the pre-v4.9 behavior just need to override the
 * `_convertToShares` and `_convertToAssets` functions.
 *
 * To learn more, check out our xref:ROOT:erc4626.adoc[ERC-4626 guide].
 * ====
 */
abstract contract ERC4626 is ERC20, IERC4626 {
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    /**
     * @dev Attempted to deposit more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxDeposit(
        address receiver,
        uint256 assets,
        uint256 max
    );

    /**
     * @dev Attempted to mint more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);

    /**
     * @dev Attempted to withdraw more assets than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxWithdraw(
        address owner,
        uint256 assets,
        uint256 max
    );

    /**
     * @dev Attempted to redeem more shares than the max amount for `receiver`.
     */
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);

    /**
     * @dev Set the underlying asset contract. This must be an ERC20-compatible contract (ERC-20 or ERC-777).
     */
    constructor(IERC20 asset_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = asset_;
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
    function _tryGetAssetDecimals(
        IERC20 asset_
    ) private view returns (bool ok, uint8 assetDecimals) {
        (bool success, bytes memory encodedDecimals) = address(asset_)
            .staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    /**
     * @dev Decimals are computed by adding the decimal offset on top of the underlying asset's decimals. This
     * "original" value is cached during construction of the vault contract. If this read operation fails (e.g., the
     * asset has not been created yet), a default of 18 is used to represent the underlying asset's decimals.
     *
     * See {IERC20Metadata-decimals}.
     */
    function decimals()
        public
        view
        virtual
        override(IERC20Metadata, ERC20)
        returns (uint8)
    {
        return _underlyingDecimals + _decimalsOffset();
    }

    /** @dev See {IERC4626-asset}. */
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view virtual returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /** @dev See {IERC4626-convertToShares}. */
    function convertToShares(
        uint256 assets
    ) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /** @dev See {IERC4626-convertToAssets}. */
    function convertToAssets(
        uint256 shares
    ) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxMint}. */
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return _convertToAssets(balanceOf(owner), Math.Rounding.Floor);
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf(owner);
    }

    /** @dev See {IERC4626-previewDeposit}. */
    function previewDeposit(
        uint256 assets
    ) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Floor);
    }

    /** @dev See {IERC4626-previewMint}. */
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Ceil);
    }

    /** @dev See {IERC4626-previewWithdraw}. */
    function previewWithdraw(
        uint256 assets
    ) public view virtual returns (uint256) {
        return _convertToShares(assets, Math.Rounding.Ceil);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(
        uint256 shares
    ) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-mint}. */
    function mint(
        uint256 shares,
        address receiver
    ) public virtual returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);

        return assets;
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @dev Internal conversion function (from assets to shares) with support for rounding direction.
     */
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return
            assets.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(),
                totalAssets() + 1,
                rounding
            );
    }

    /**
     * @dev Internal conversion function (from shares to assets) with support for rounding direction.
     */
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding
    ) internal view virtual returns (uint256) {
        return
            shares.mulDiv(
                totalAssets() + 1,
                totalSupply() + 10 ** _decimalsOffset(),
                rounding
            );
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        // If _asset is ERC-777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(_asset, caller, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // If _asset is ERC-777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, shares);
        SafeERC20.safeTransfer(_asset, receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }
}

// src/interfaces/IFleetCommanderConfigProvider.sol

/**
 * @title IFleetCommander Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommanderConfigProvider is
    IFleetCommanderConfigProviderErrors,
    IFleetCommanderConfigProviderEvents
{
    /**
     * @notice Retrieves the ark address at the specified index
     * @param index The index of the ark in the arks array
     * @return The address of the ark at the specified index
     */
    function arks(uint256 index) external view returns (address);

    /**
     * @notice Retrieves the arks currently linked to fleet (excluding the buffer ark)
     */
    function getActiveArks() external view returns (address[] memory);

    /**
     * @notice Retrieves the current fleet config
     */
    function getConfig() external view returns (FleetConfig memory);

    /**
     * @notice Retrieves the buffer ark address
     */
    function bufferArk() external view returns (address);

    /**
     * @notice Checks if the ark is part of the fleet or is the buffer ark
     * @param ark The address of the Ark
     * @return bool Returns true if the ark is active or the buffer ark, false otherwise.
     */
    function isArkActiveOrBufferArk(address ark) external view returns (bool);

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Adds a new Ark
     * @param ark The address of the new Ark
     */
    function addArk(address ark) external;

    /**
     * @notice Removes an existing Ark
     * @param ark The address of the Ark to remove
     */
    function removeArk(address ark) external;

    /**
     * @notice Sets a new deposit cap for Fleet
     * @param newDepositCap The new deposit cap
     */
    function setFleetDepositCap(uint256 newDepositCap) external;

    /**
     * @notice Sets a new deposit cap for an Ark
     * @param ark The address of the Ark
     * @param newDepositCap The new deposit cap
     */
    function setArkDepositCap(address ark, uint256 newDepositCap) external;

    /**
     * @notice Sets the max deposit percentage of TVL for an Ark
     * @param ark The address of the Ark
     * @param newMaxDepositPercentageOfTVL The new max deposit percentage of TVL
     */
    function setArkMaxDepositPercentageOfTVL(
        address ark,
        Percentage newMaxDepositPercentageOfTVL
    ) external;

    /**
     * @dev Sets the minimum buffer balance for the fleet commander.
     * @param newMinimumBalance The new minimum buffer balance to be set.
     */
    function setMinimumBufferBalance(uint256 newMinimumBalance) external;

    /**
     * @dev Sets the minimum number of allowe rebalance operations.
     * @param newMaxRebalanceOperations The new maximum allowed rebalance operations.
     */
    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external;

    /**
     * @notice Sets the maxRebalanceOutflow for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMaxRebalanceOutflow The new maxRebalanceOutflow value
     */
    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external;

    /**
     * @notice Sets the maxRebalanceInflow for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMaxRebalanceInflow The new maxRebalanceInflow value
     */
    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external;

    /**
     * @notice Deploys and sets the staking rewards manager contract address
     */
    function updateStakingRewardsManager() external;

    /**
     * @notice Enables or disables transfers of fleet commander shares
     * @dev Only callable by the governor when not paused
     */
    function setFleetTokenTransferability() external;
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd1x18/Casting.sol

/// @notice Casts an SD1x18 number into SD59x18.
/// @dev There is no overflow check because SD1x18 ⊆ SD59x18.
function intoSD59x18_0(SD1x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(SD1x18.unwrap(x)));
}

/// @notice Casts an SD1x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_0(SD1x18 x) pure returns (UD60x18 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
function intoUint128_0(SD1x18 x) pure returns (uint128 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint128_Underflow(x);
    }
    result = uint128(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_0(SD1x18 x) pure returns (uint256 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint256_Underflow(x);
    }
    result = uint256(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_0(SD1x18 x) pure returns (uint40 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint40_Underflow(x);
    }
    if (xInt > int64(uint64(MAX_UINT40))) {
        revert PRBMath_SD1x18_ToUint40_Overflow(x);
    }
    result = uint40(uint64(xInt));
}

/// @notice Alias for {wrap}.
function sd1x18(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

/// @notice Unwraps an SD1x18 number into int64.
function unwrap_0(SD1x18 x) pure returns (int64 result) {
    result = SD1x18.unwrap(x);
}

/// @notice Wraps an int64 number into SD1x18.
function wrap_0(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd1x18/Constants.sol

/// @dev Euler's number as an SD1x18 number.
SD1x18 constant E_0 = SD1x18.wrap(2_718281828459045235);

/// @dev The maximum value an SD1x18 number can have.
int64 constant uMAX_SD1x18 = 9_223372036854775807;
SD1x18 constant MAX_SD1x18 = SD1x18.wrap(uMAX_SD1x18);

/// @dev The minimum value an SD1x18 number can have.
int64 constant uMIN_SD1x18 = -9_223372036854775808;
SD1x18 constant MIN_SD1x18 = SD1x18.wrap(uMIN_SD1x18);

/// @dev PI as an SD1x18 number.
SD1x18 constant PI_0 = SD1x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD1x18.
SD1x18 constant UNIT_1 = SD1x18.wrap(1e18);
int64 constant uUNIT_0 = 1e18;

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd1x18/Errors.sol

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in UD60x18.
error PRBMath_SD1x18_ToUD60x18_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint128.
error PRBMath_SD1x18_ToUint128_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint256.
error PRBMath_SD1x18_ToUint256_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Overflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Underflow(SD1x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd1x18/ValueType.sol

/// @notice The signed 1.18-decimal fixed-point number representation, which can have up to 1 digit and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int64. This is useful when end users want to use int64 to save gas, e.g. with tight variable packing in contract
/// storage.
type SD1x18 is int64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_0,
    intoUD60x18_0,
    intoUint128_0,
    intoUint256_0,
    intoUint40_0,
    unwrap_0
} for SD1x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd21x18/Casting.sol

/// @notice Casts an SD21x18 number into SD59x18.
/// @dev There is no overflow check because SD21x18 ⊆ SD59x18.
function intoSD59x18_1(SD21x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(SD21x18.unwrap(x)));
}

/// @notice Casts an SD21x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_1(SD21x18 x) pure returns (UD60x18 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint128(xInt));
}

/// @notice Casts an SD21x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
function intoUint128_1(SD21x18 x) pure returns (uint128 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint128_Underflow(x);
    }
    result = uint128(xInt);
}

/// @notice Casts an SD21x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_1(SD21x18 x) pure returns (uint256 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint256_Underflow(x);
    }
    result = uint256(uint128(xInt));
}

/// @notice Casts an SD21x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_1(SD21x18 x) pure returns (uint40 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint40_Underflow(x);
    }
    if (xInt > int128(uint128(MAX_UINT40))) {
        revert PRBMath_SD21x18_ToUint40_Overflow(x);
    }
    result = uint40(uint128(xInt));
}

/// @notice Alias for {wrap}.
function sd21x18(int128 x) pure returns (SD21x18 result) {
    result = SD21x18.wrap(x);
}

/// @notice Unwraps an SD21x18 number into int128.
function unwrap_1(SD21x18 x) pure returns (int128 result) {
    result = SD21x18.unwrap(x);
}

/// @notice Wraps an int128 number into SD21x18.
function wrap_1(int128 x) pure returns (SD21x18 result) {
    result = SD21x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd21x18/Constants.sol

/// @dev Euler's number as an SD21x18 number.
SD21x18 constant E_1 = SD21x18.wrap(2_718281828459045235);

/// @dev The maximum value an SD21x18 number can have.
int128 constant uMAX_SD21x18 = 170141183460469231731_687303715884105727;
SD21x18 constant MAX_SD21x18 = SD21x18.wrap(uMAX_SD21x18);

/// @dev The minimum value an SD21x18 number can have.
int128 constant uMIN_SD21x18 = -170141183460469231731_687303715884105728;
SD21x18 constant MIN_SD21x18 = SD21x18.wrap(uMIN_SD21x18);

/// @dev PI as an SD21x18 number.
SD21x18 constant PI_1 = SD21x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD21x18.
SD21x18 constant UNIT_2 = SD21x18.wrap(1e18);
int128 constant uUNIT_1 = 1e18;

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd21x18/Errors.sol

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint128.
error PRBMath_SD21x18_ToUint128_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in UD60x18.
error PRBMath_SD21x18_ToUD60x18_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint256.
error PRBMath_SD21x18_ToUint256_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint40.
error PRBMath_SD21x18_ToUint40_Overflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint40.
error PRBMath_SD21x18_ToUint40_Underflow(SD21x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd21x18/ValueType.sol

/// @notice The signed 21.18-decimal fixed-point number representation, which can have up to 21 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int128. This is useful when end users want to use int128 to save gas, e.g. with tight variable packing in contract
/// storage.
type SD21x18 is int128;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_1,
    intoUD60x18_1,
    intoUint128_1,
    intoUint256_1,
    intoUint40_1,
    unwrap_1
} for SD21x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/Casting.sol

/// @notice Casts an SD59x18 number into int256.
/// @dev This is basically a functional alias for {unwrap}.
function intoInt256(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Casts an SD59x18 number into SD1x18.
/// @dev Requirements:
/// - x ≥ uMIN_SD1x18
/// - x ≤ uMAX_SD1x18
function intoSD1x18_0(SD59x18 x) pure returns (SD1x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD1x18) {
        revert PRBMath_SD59x18_IntoSD1x18_Underflow(x);
    }
    if (xInt > uMAX_SD1x18) {
        revert PRBMath_SD59x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(xInt));
}

/// @notice Casts an SD59x18 number into SD21x18.
/// @dev Requirements:
/// - x ≥ uMIN_SD21x18
/// - x ≤ uMAX_SD21x18
function intoSD21x18_0(SD59x18 x) pure returns (SD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD21x18) {
        revert PRBMath_SD59x18_IntoSD21x18_Underflow(x);
    }
    if (xInt > uMAX_SD21x18) {
        revert PRBMath_SD59x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(xInt));
}

/// @notice Casts an SD59x18 number into UD2x18.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UD2x18
function intoUD2x18_0(SD59x18 x) pure returns (UD2x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD2x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD2x18))) {
        revert PRBMath_SD59x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(uint256(xInt)));
}

/// @notice Casts an SD59x18 number into UD21x18.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UD21x18
function intoUD21x18_0(SD59x18 x) pure returns (UD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD21x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD21x18))) {
        revert PRBMath_SD59x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(uint256(xInt)));
}

/// @notice Casts an SD59x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_2(SD59x18 x) pure returns (UD60x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_2(SD59x18 x) pure returns (uint256 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint256_Underflow(x);
    }
    result = uint256(xInt);
}

/// @notice Casts an SD59x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UINT128
function intoUint128_2(SD59x18 x) pure returns (uint128 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint128_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT128))) {
        revert PRBMath_SD59x18_IntoUint128_Overflow(x);
    }
    result = uint128(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_2(SD59x18 x) pure returns (uint40 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint40_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT40))) {
        revert PRBMath_SD59x18_IntoUint40_Overflow(x);
    }
    result = uint40(uint256(xInt));
}

/// @notice Alias for {wrap}.
function sd(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Alias for {wrap}.
function sd59x18(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Unwraps an SD59x18 number into int256.
function unwrap_2(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Wraps an int256 number into SD59x18.
function wrap_2(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/Constants.sol

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as an SD59x18 number.
SD59x18 constant E_2 = SD59x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
int256 constant uEXP_MAX_INPUT_0 = 133_084258667509499440;
SD59x18 constant EXP_MAX_INPUT_0 = SD59x18.wrap(uEXP_MAX_INPUT_0);

/// @dev Any value less than this returns 0 in {exp}.
int256 constant uEXP_MIN_THRESHOLD = -41_446531673892822322;
SD59x18 constant EXP_MIN_THRESHOLD = SD59x18.wrap(uEXP_MIN_THRESHOLD);

/// @dev The maximum input permitted in {exp2}.
int256 constant uEXP2_MAX_INPUT_0 = 192e18 - 1;
SD59x18 constant EXP2_MAX_INPUT_0 = SD59x18.wrap(uEXP2_MAX_INPUT_0);

/// @dev Any value less than this returns 0 in {exp2}.
int256 constant uEXP2_MIN_THRESHOLD = -59_794705707972522261;
SD59x18 constant EXP2_MIN_THRESHOLD = SD59x18.wrap(uEXP2_MIN_THRESHOLD);

/// @dev Half the UNIT number.
int256 constant uHALF_UNIT_0 = 0.5e18;
SD59x18 constant HALF_UNIT_0 = SD59x18.wrap(uHALF_UNIT_0);

/// @dev $log_2(10)$ as an SD59x18 number.
int256 constant uLOG2_10_0 = 3_321928094887362347;
SD59x18 constant LOG2_10_0 = SD59x18.wrap(uLOG2_10_0);

/// @dev $log_2(e)$ as an SD59x18 number.
int256 constant uLOG2_E_0 = 1_442695040888963407;
SD59x18 constant LOG2_E_0 = SD59x18.wrap(uLOG2_E_0);

/// @dev The maximum value an SD59x18 number can have.
int256 constant uMAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_792003956564819967;
SD59x18 constant MAX_SD59x18 = SD59x18.wrap(uMAX_SD59x18);

/// @dev The maximum whole value an SD59x18 number can have.
int256 constant uMAX_WHOLE_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MAX_WHOLE_SD59x18 = SD59x18.wrap(uMAX_WHOLE_SD59x18);

/// @dev The minimum value an SD59x18 number can have.
int256 constant uMIN_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_792003956564819968;
SD59x18 constant MIN_SD59x18 = SD59x18.wrap(uMIN_SD59x18);

/// @dev The minimum whole value an SD59x18 number can have.
int256 constant uMIN_WHOLE_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MIN_WHOLE_SD59x18 = SD59x18.wrap(uMIN_WHOLE_SD59x18);

/// @dev PI as an SD59x18 number.
SD59x18 constant PI_2 = SD59x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD59x18.
int256 constant uUNIT_2 = 1e18;
SD59x18 constant UNIT_3 = SD59x18.wrap(1e18);

/// @dev The unit number squared.
int256 constant uUNIT_SQUARED_0 = 1e36;
SD59x18 constant UNIT_SQUARED_0 = SD59x18.wrap(uUNIT_SQUARED_0);

/// @dev Zero as an SD59x18 number.
SD59x18 constant ZERO_0 = SD59x18.wrap(0);

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/Errors.sol

/// @notice Thrown when taking the absolute value of `MIN_SD59x18`.
error PRBMath_SD59x18_Abs_MinSD59x18();

/// @notice Thrown when ceiling a number overflows SD59x18.
error PRBMath_SD59x18_Ceil_Overflow(SD59x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMath_SD59x18_Convert_Overflow(int256 x);

/// @notice Thrown when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMath_SD59x18_Convert_Underflow(int256 x);

/// @notice Thrown when dividing two numbers and one of them is `MIN_SD59x18`.
error PRBMath_SD59x18_Div_InputTooSmall();

/// @notice Thrown when dividing two numbers and one of the intermediary unsigned results overflows SD59x18.
error PRBMath_SD59x18_Div_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_SD59x18_Exp_InputTooBig(SD59x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_SD59x18_Exp2_InputTooBig(SD59x18 x);

/// @notice Thrown when flooring a number underflows SD59x18.
error PRBMath_SD59x18_Floor_Underflow(SD59x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and their product is negative.
error PRBMath_SD59x18_Gm_NegativeProduct(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows SD59x18.
error PRBMath_SD59x18_Gm_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD21x18.
error PRBMath_SD59x18_IntoSD21x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD21x18.
error PRBMath_SD59x18_IntoSD21x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD21x18.
error PRBMath_SD59x18_IntoUD21x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD21x18.
error PRBMath_SD59x18_IntoUD21x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD60x18.
error PRBMath_SD59x18_IntoUD60x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint256.
error PRBMath_SD59x18_IntoUint256_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Underflow(SD59x18 x);

/// @notice Thrown when taking the logarithm of a number less than or equal to zero.
error PRBMath_SD59x18_Log_InputTooSmall(SD59x18 x);

/// @notice Thrown when multiplying two numbers and one of the inputs is `MIN_SD59x18`.
error PRBMath_SD59x18_Mul_InputTooSmall();

/// @notice Thrown when multiplying two numbers and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Mul_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when raising a number to a power and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Powu_Overflow(SD59x18 x, uint256 y);

/// @notice Thrown when taking the square root of a negative number.
error PRBMath_SD59x18_Sqrt_NegativeInput(SD59x18 x);

/// @notice Thrown when the calculating the square root overflows SD59x18.
error PRBMath_SD59x18_Sqrt_Overflow(SD59x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/Helpers.sol

/// @notice Implements the checked addition operation (+) in the SD59x18 type.
function add_1(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() + y.unwrap_2());
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and_0(SD59x18 x, int256 bits) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and2_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() & y.unwrap_2());
}

/// @notice Implements the equal (=) operation in the SD59x18 type.
function eq_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() == y.unwrap_2();
}

/// @notice Implements the greater than operation (>) in the SD59x18 type.
function gt_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() > y.unwrap_2();
}

/// @notice Implements the greater than or equal to operation (>=) in the SD59x18 type.
function gte_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() >= y.unwrap_2();
}

/// @notice Implements a zero comparison check function in the SD59x18 type.
function isZero_0(SD59x18 x) pure returns (bool result) {
    result = x.unwrap_2() == 0;
}

/// @notice Implements the left shift operation (<<) in the SD59x18 type.
function lshift_0(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() << bits);
}

/// @notice Implements the lower than operation (<) in the SD59x18 type.
function lt_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() < y.unwrap_2();
}

/// @notice Implements the lower than or equal to operation (<=) in the SD59x18 type.
function lte_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() <= y.unwrap_2();
}

/// @notice Implements the unchecked modulo operation (%) in the SD59x18 type.
function mod_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() % y.unwrap_2());
}

/// @notice Implements the not equal operation (!=) in the SD59x18 type.
function neq_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() != y.unwrap_2();
}

/// @notice Implements the NOT (~) bitwise operation in the SD59x18 type.
function not_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(~x.unwrap_2());
}

/// @notice Implements the OR (|) bitwise operation in the SD59x18 type.
function or_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() | y.unwrap_2());
}

/// @notice Implements the right shift operation (>>) in the SD59x18 type.
function rshift_0(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the SD59x18 type.
function sub_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() - y.unwrap_2());
}

/// @notice Implements the checked unary minus operation (-) in the SD59x18 type.
function unary(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(-x.unwrap_2());
}

/// @notice Implements the unchecked addition operation (+) in the SD59x18 type.
function uncheckedAdd_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(x.unwrap_2() + y.unwrap_2());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the SD59x18 type.
function uncheckedSub_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(x.unwrap_2() - y.unwrap_2());
    }
}

/// @notice Implements the unchecked unary minus operation (-) in the SD59x18 type.
function uncheckedUnary(SD59x18 x) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(-x.unwrap_2());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the SD59x18 type.
function xor_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() ^ y.unwrap_2());
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/Math.sol

/// @notice Calculates the absolute value of x.
///
/// @dev Requirements:
/// - x > MIN_SD59x18.
///
/// @param x The SD59x18 number for which to calculate the absolute value.
/// @return result The absolute value of x as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function abs(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Abs_MinSD59x18();
    }
    result = xInt < 0 ? wrap_2(-xInt) : x;
}

/// @notice Calculates the arithmetic average of x and y.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The arithmetic average as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();

    unchecked {
        // This operation is equivalent to `x / 2 +  y / 2`, and it can never overflow.
        int256 sum = (xInt >> 1) + (yInt >> 1);

        if (sum < 0) {
            // If at least one of x and y is odd, add 1 to the result, because shifting negative numbers to the right
            // rounds toward negative infinity. The right part is equivalent to `sum + (x % 2 == 1 || y % 2 == 1)`.
            assembly ("memory-safe") {
                result := add(sum, and(or(xInt, yInt), 1))
            }
        } else {
            // Add 1 if both x and y are odd to account for the double 0.5 remainder truncated after shifting.
            result = wrap_2(sum + (xInt & yInt & 1));
        }
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≤ MAX_WHOLE_SD59x18
///
/// @param x The SD59x18 number to ceil.
/// @return result The smallest whole number greater than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt > uMAX_WHOLE_SD59x18) {
        revert PRBMath_SD59x18_Ceil_Overflow(x);
    }

    int256 remainder = xInt % uUNIT_2;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt > 0) {
                resultInt += uUNIT_2;
            }
            result = wrap_2(resultInt);
        }
    }
}

/// @notice Divides two SD59x18 numbers, returning a new SD59x18 number.
///
/// @dev This is an extension of {Common.mulDiv} for signed numbers, which works by computing the signs and the absolute
/// values separately.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The denominator must not be zero.
/// - The result must fit in SD59x18.
///
/// @param x The numerator as an SD59x18 number.
/// @param y The denominator as an SD59x18 number.
/// @return result The quotient as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function div_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Div_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*UNIT÷y). The resulting value must fit in SD59x18.
    uint256 resultAbs = mulDiv(xAbs, uint256(uUNIT_2), yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Div_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap_2(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}.
///
/// Requirements:
/// - Refer to the requirements in {exp2}.
/// - x < 133_084258667509499441.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();

    // Any input less than the threshold returns zero.
    // This check also prevents an overflow for very small numbers.
    if (xInt < uEXP_MIN_THRESHOLD) {
        return ZERO_0;
    }

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xInt > uEXP_MAX_INPUT_0) {
        revert PRBMath_SD59x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        int256 doubleUnitProduct = xInt * uLOG2_E_0;
        result = exp2_1(wrap_2(doubleUnitProduct / uUNIT_2));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method using the following formula:
///
/// $$
/// 2^{-x} = \frac{1}{2^x}
/// $$
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693.
///
/// Notes:
/// - If x < -59_794705707972522261, the result is zero.
///
/// Requirements:
/// - x < 192e18.
/// - The result must fit in SD59x18.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2_1(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        // The inverse of any number less than the threshold is truncated to zero.
        if (xInt < uEXP2_MIN_THRESHOLD) {
            return ZERO_0;
        }

        unchecked {
            // Inline the fixed-point inversion to save gas.
            result = wrap_2(uUNIT_SQUARED_0 / exp2_1(wrap_2(-xInt)).unwrap_2());
        }
    } else {
        // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
        if (xInt > uEXP2_MAX_INPUT_0) {
            revert PRBMath_SD59x18_Exp2_InputTooBig(x);
        }

        unchecked {
            // Convert x to the 192.64-bit fixed-point format.
            uint256 x_192x64 = uint256((xInt << 64) / uUNIT_2);

            // It is safe to cast the result to int256 due to the checks above.
            result = wrap_2(int256(exp2_0(x_192x64)));
        }
    }
}

/// @notice Yields the greatest whole number less than or equal to x.
///
/// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≥ MIN_WHOLE_SD59x18
///
/// @param x The SD59x18 number to floor.
/// @return result The greatest whole number less than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < uMIN_WHOLE_SD59x18) {
        revert PRBMath_SD59x18_Floor_Underflow(x);
    }

    int256 remainder = xInt % uUNIT_2;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt < 0) {
                resultInt -= uUNIT_2;
            }
            result = wrap_2(resultInt);
        }
    }
}

/// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right.
/// of the radix point for negative numbers.
/// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
/// @param x The SD59x18 number to get the fractional part of.
/// @return result The fractional part of x as an SD59x18 number.
function frac_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() % uUNIT_2);
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x * y must fit in SD59x18.
/// - x * y must not be negative, since complex numbers are not supported.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == 0 || yInt == 0) {
        return ZERO_0;
    }

    unchecked {
        // Equivalent to `xy / x != y`. Checking for overflow this way is faster than letting Solidity do it.
        int256 xyInt = xInt * yInt;
        if (xyInt / xInt != yInt) {
            revert PRBMath_SD59x18_Gm_Overflow(x, y);
        }

        // The product must not be negative, since complex numbers are not supported.
        if (xyInt < 0) {
            revert PRBMath_SD59x18_Gm_NegativeProduct(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        uint256 resultUint = sqrt_0(uint256(xyInt));
        result = wrap_2(int256(resultUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The SD59x18 number for which to calculate the inverse.
/// @return result The inverse as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(uUNIT_SQUARED_0 / x.unwrap_2());
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln_0(SD59x18 x) pure returns (SD59x18 result) {
    // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
    // {log2} can return is ~195_205294292027477728.
    result = wrap_2((log2_0(x).unwrap_2() * uUNIT_2) / uLOG2_E_0);
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        revert PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this block is the standard multiplication operation, not {SD59x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT_2, sub(0, 18)) }
        case 10 { result := mul(uUNIT_2, sub(1, 18)) }
        case 100 { result := mul(uUNIT_2, sub(2, 18)) }
        case 1000 { result := mul(uUNIT_2, sub(3, 18)) }
        case 10000 { result := mul(uUNIT_2, sub(4, 18)) }
        case 100000 { result := mul(uUNIT_2, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT_2, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT_2, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT_2, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT_2, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT_2, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT_2, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT_2, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT_2, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT_2, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT_2, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT_2, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT_2, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT_2 }
        case 100000000000000000000 { result := mul(uUNIT_2, 2) }
        case 1000000000000000000000 { result := mul(uUNIT_2, 3) }
        case 10000000000000000000000 { result := mul(uUNIT_2, 4) }
        case 100000000000000000000000 { result := mul(uUNIT_2, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT_2, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT_2, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT_2, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT_2, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT_2, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT_2, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT_2, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT_2, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT_2, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT_2, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT_2, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT_2, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT_2, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT_2, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT_2, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT_2, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT_2, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT_2, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 58) }
        default { result := uMAX_SD59x18 }
    }

    if (result.unwrap_2() == uMAX_SD59x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap_2((log2_0(x).unwrap_2() * uUNIT_2) / uLOG2_10_0);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation.
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x > 0
///
/// @param x The SD59x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt <= 0) {
        revert PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    unchecked {
        int256 sign;
        if (xInt >= uUNIT_2) {
            sign = 1;
        } else {
            sign = -1;
            // Inline the fixed-point inversion to save gas.
            xInt = uUNIT_SQUARED_0 / xInt;
        }

        // Calculate the integer part of the logarithm.
        uint256 n = msb(uint256(xInt / uUNIT_2));

        // This is the integer part of the logarithm as an SD59x18 number. The operation can't overflow
        // because n is at most 255, `UNIT` is 1e18, and the sign is either 1 or -1.
        int256 resultInt = int256(n) * uUNIT_2;

        // Calculate $y = x * 2^{-n}$.
        int256 y = xInt >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT_2) {
            return wrap_2(resultInt * sign);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        int256 DOUBLE_UNIT = 2e18;
        for (int256 delta = uHALF_UNIT_0; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT_2;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultInt = resultInt + delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        resultInt *= sign;
        result = wrap_2(resultInt);
    }
}

/// @notice Multiplies two SD59x18 numbers together, returning a new SD59x18 number.
///
/// @dev Notes:
/// - Refer to the notes in {Common.mulDiv18}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv18}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The result must fit in SD59x18.
///
/// @param x The multiplicand as an SD59x18 number.
/// @param y The multiplier as an SD59x18 number.
/// @return result The product as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Mul_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*y÷UNIT). The resulting value must fit in SD59x18.
    uint256 resultAbs = mulDiv18(xAbs, yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Mul_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap_2(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Raises x to the power of y using the following formula:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}, {log2}, and {mul}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as an SD59x18 number.
/// @param y Exponent to raise x to, as an SD59x18 number
/// @return result x raised to power y, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xInt == 0) {
        return yInt == 0 ? UNIT_3 : ZERO_0;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xInt == uUNIT_2) {
        return UNIT_3;
    }

    // If y is zero, the result is always `UNIT`.
    if (yInt == 0) {
        return UNIT_3;
    }
    // If y is `UNIT`, the result is always x.
    else if (yInt == uUNIT_2) {
        return x;
    }

    // Calculate the result using the formula.
    result = exp2_1(mul_0(log2_0(x), y));
}

/// @notice Raises x (an SD59x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {abs} and {Common.mulDiv18}.
/// - The result must fit in SD59x18.
///
/// @param x The base as an SD59x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu_0(SD59x18 x, uint256 y) pure returns (SD59x18 result) {
    uint256 xAbs = uint256(abs(x).unwrap_2());

    // Calculate the first iteration of the loop in advance.
    uint256 resultAbs = y & 1 > 0 ? xAbs : uint256(uUNIT_2);

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    uint256 yAux = y;
    for (yAux >>= 1; yAux > 0; yAux >>= 1) {
        xAbs = mulDiv18(xAbs, xAbs);

        // Equivalent to `y % 2 == 1`.
        if (yAux & 1 > 0) {
            resultAbs = mulDiv18(resultAbs, xAbs);
        }
    }

    // The result must fit in SD59x18.
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Powu_Overflow(x, y);
    }

    unchecked {
        // Is the base negative and the exponent odd? If yes, the result should be negative.
        int256 resultInt = int256(resultAbs);
        bool isNegative = x.unwrap_2() < 0 && y & 1 == 1;
        if (isNegative) {
            resultInt = -resultInt;
        }
        result = wrap_2(resultInt);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - Only the positive root is returned.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x ≥ 0, since complex numbers are not supported.
/// - x ≤ MAX_SD59x18 / UNIT
///
/// @param x The SD59x18 number for which to calculate the square root.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt_1(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        revert PRBMath_SD59x18_Sqrt_NegativeInput(x);
    }
    if (xInt > uMAX_SD59x18 / uUNIT_2) {
        revert PRBMath_SD59x18_Sqrt_Overflow(x);
    }

    unchecked {
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two SD59x18 numbers.
        // In this case, the two numbers are both the square root.
        uint256 resultUint = sqrt_0(uint256(xInt * uUNIT_2));
        result = wrap_2(int256(resultUint));
    }
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/sd59x18/ValueType.sol

/// @notice The signed 59.18-decimal fixed-point number representation, which can have up to 59 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int256.
type SD59x18 is int256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoInt256,
    intoSD1x18_0,
    intoSD21x18_0,
    intoUD2x18_0,
    intoUD21x18_0,
    intoUD60x18_2,
    intoUint256_2,
    intoUint128_2,
    intoUint40_2,
    unwrap_2
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    abs,
    avg_0,
    ceil_0,
    div_0,
    exp_0,
    exp2_1,
    floor_0,
    frac_0,
    gm_0,
    inv_0,
    log10_0,
    log2_0,
    ln_0,
    mul_0,
    pow_0,
    powu_0,
    sqrt_1
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    add_1,
    and_0,
    eq_0,
    gt_0,
    gte_0,
    isZero_0,
    lshift_0,
    lt_0,
    lte_0,
    mod_0,
    neq_0,
    not_0,
    or_0,
    rshift_0,
    sub_0,
    uncheckedAdd_0,
    uncheckedSub_0,
    uncheckedUnary,
    xor_0
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the SD59x18 type.
using {
    add_1 as +,
    and2_0 as &,
    div_0 as /,
    eq_0 as ==,
    gt_0 as >,
    gte_0 as >=,
    lt_0 as <,
    lte_0 as <=,
    mod_0 as %,
    mul_0 as *,
    neq_0 as !=,
    not_0 as ~,
    or_0 as |,
    sub_0 as -,
    unary as -,
    xor_0 as ^
} for SD59x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud21x18/Casting.sol

/// @notice Casts a UD21x18 number into SD59x18.
/// @dev There is no overflow check because UD21x18 ⊆ SD59x18.
function intoSD59x18_2(UD21x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD21x18.unwrap(x))));
}

/// @notice Casts a UD21x18 number into UD60x18.
/// @dev There is no overflow check because UD21x18 ⊆ UD60x18.
function intoUD60x18_3(UD21x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD21x18.unwrap(x));
}

/// @notice Casts a UD21x18 number into uint128.
/// @dev This is basically an alias for {unwrap}.
function intoUint128_3(UD21x18 x) pure returns (uint128 result) {
    result = UD21x18.unwrap(x);
}

/// @notice Casts a UD21x18 number into uint256.
/// @dev There is no overflow check because UD21x18 ⊆ uint256.
function intoUint256_3(UD21x18 x) pure returns (uint256 result) {
    result = uint256(UD21x18.unwrap(x));
}

/// @notice Casts a UD21x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_3(UD21x18 x) pure returns (uint40 result) {
    uint128 xUint = UD21x18.unwrap(x);
    if (xUint > uint128(MAX_UINT40)) {
        revert PRBMath_UD21x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud21x18(uint128 x) pure returns (UD21x18 result) {
    result = UD21x18.wrap(x);
}

/// @notice Unwrap a UD21x18 number into uint128.
function unwrap_3(UD21x18 x) pure returns (uint128 result) {
    result = UD21x18.unwrap(x);
}

/// @notice Wraps a uint128 number into UD21x18.
function wrap_3(uint128 x) pure returns (UD21x18 result) {
    result = UD21x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud21x18/Constants.sol

/// @dev Euler's number as a UD21x18 number.
UD21x18 constant E_3 = UD21x18.wrap(2_718281828459045235);

/// @dev The maximum value a UD21x18 number can have.
uint128 constant uMAX_UD21x18 = 340282366920938463463_374607431768211455;
UD21x18 constant MAX_UD21x18 = UD21x18.wrap(uMAX_UD21x18);

/// @dev PI as a UD21x18 number.
UD21x18 constant PI_3 = UD21x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD21x18.
uint256 constant uUNIT_3 = 1e18;
UD21x18 constant UNIT_4 = UD21x18.wrap(1e18);

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud21x18/Errors.sol

/// @notice Thrown when trying to cast a UD21x18 number that doesn't fit in uint40.
error PRBMath_UD21x18_IntoUint40_Overflow(UD21x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud21x18/ValueType.sol

/// @notice The unsigned 21.18-decimal fixed-point number representation, which can have up to 21 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type uint128. This is useful when end users want to use uint128 to save gas, e.g. with tight variable packing in contract
/// storage.
type UD21x18 is uint128;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_2,
    intoUD60x18_3,
    intoUint128_3,
    intoUint256_3,
    intoUint40_3,
    unwrap_3
} for UD21x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud2x18/Casting.sol

/// @notice Casts a UD2x18 number into SD59x18.
/// @dev There is no overflow check because UD2x18 ⊆ SD59x18.
function intoSD59x18_3(UD2x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD2x18.unwrap(x))));
}

/// @notice Casts a UD2x18 number into UD60x18.
/// @dev There is no overflow check because UD2x18 ⊆ UD60x18.
function intoUD60x18_4(UD2x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint128.
/// @dev There is no overflow check because UD2x18 ⊆ uint128.
function intoUint128_4(UD2x18 x) pure returns (uint128 result) {
    result = uint128(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint256.
/// @dev There is no overflow check because UD2x18 ⊆ uint256.
function intoUint256_4(UD2x18 x) pure returns (uint256 result) {
    result = uint256(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_4(UD2x18 x) pure returns (uint40 result) {
    uint64 xUint = UD2x18.unwrap(x);
    if (xUint > uint64(MAX_UINT40)) {
        revert PRBMath_UD2x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud2x18(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

/// @notice Unwrap a UD2x18 number into uint64.
function unwrap_4(UD2x18 x) pure returns (uint64 result) {
    result = UD2x18.unwrap(x);
}

/// @notice Wraps a uint64 number into UD2x18.
function wrap_4(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud2x18/Constants.sol

/// @dev Euler's number as a UD2x18 number.
UD2x18 constant E_4 = UD2x18.wrap(2_718281828459045235);

/// @dev The maximum value a UD2x18 number can have.
uint64 constant uMAX_UD2x18 = 18_446744073709551615;
UD2x18 constant MAX_UD2x18 = UD2x18.wrap(uMAX_UD2x18);

/// @dev PI as a UD2x18 number.
UD2x18 constant PI_4 = UD2x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD2x18.
UD2x18 constant UNIT_5 = UD2x18.wrap(1e18);
uint64 constant uUNIT_4 = 1e18;

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud2x18/Errors.sol

/// @notice Thrown when trying to cast a UD2x18 number that doesn't fit in uint40.
error PRBMath_UD2x18_IntoUint40_Overflow(UD2x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud2x18/ValueType.sol

/// @notice The unsigned 2.18-decimal fixed-point number representation, which can have up to 2 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type uint64. This is useful when end users want to use uint64 to save gas, e.g. with tight variable packing in contract
/// storage.
type UD2x18 is uint64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_3,
    intoUD60x18_4,
    intoUint128_4,
    intoUint256_4,
    intoUint40_4,
    unwrap_4
} for UD2x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Casting.sol

/// @notice Casts a UD60x18 number into SD1x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD1x18
function intoSD1x18_1(UD60x18 x) pure returns (SD1x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD1x18))) {
        revert PRBMath_UD60x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(uint64(xUint)));
}

/// @notice Casts a UD60x18 number into SD21x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD21x18
function intoSD21x18_1(UD60x18 x) pure returns (SD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD21x18))) {
        revert PRBMath_UD60x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(uint128(xUint)));
}

/// @notice Casts a UD60x18 number into UD2x18.
/// @dev Requirements:
/// - x ≤ uMAX_UD2x18
function intoUD2x18_1(UD60x18 x) pure returns (UD2x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD2x18) {
        revert PRBMath_UD60x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(xUint));
}

/// @notice Casts a UD60x18 number into UD21x18.
/// @dev Requirements:
/// - x ≤ uMAX_UD21x18
function intoUD21x18_1(UD60x18 x) pure returns (UD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD21x18) {
        revert PRBMath_UD60x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(xUint));
}

/// @notice Casts a UD60x18 number into SD59x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD59x18
function intoSD59x18_4(UD60x18 x) pure returns (SD59x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(uMAX_SD59x18)) {
        revert PRBMath_UD60x18_IntoSD59x18_Overflow(x);
    }
    result = SD59x18.wrap(int256(xUint));
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev This is basically an alias for {unwrap}.
function intoUint256_5(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev Requirements:
/// - x ≤ MAX_UINT128
function intoUint128_5(UD60x18 x) pure returns (uint128 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT128) {
        revert PRBMath_UD60x18_IntoUint128_Overflow(x);
    }
    result = uint128(xUint);
}

/// @notice Casts a UD60x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_5(UD60x18 x) pure returns (uint40 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT40) {
        revert PRBMath_UD60x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Alias for {wrap}.
function ud60x18(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Unwraps a UD60x18 number into uint256.
function unwrap_5(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Wraps a uint256 number into the UD60x18 value type.
function wrap_5(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Constants.sol

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as a UD60x18 number.
UD60x18 constant E_5 = UD60x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
uint256 constant uEXP_MAX_INPUT_1 = 133_084258667509499440;
UD60x18 constant EXP_MAX_INPUT_1 = UD60x18.wrap(uEXP_MAX_INPUT_1);

/// @dev The maximum input permitted in {exp2}.
uint256 constant uEXP2_MAX_INPUT_1 = 192e18 - 1;
UD60x18 constant EXP2_MAX_INPUT_1 = UD60x18.wrap(uEXP2_MAX_INPUT_1);

/// @dev Half the UNIT number.
uint256 constant uHALF_UNIT_1 = 0.5e18;
UD60x18 constant HALF_UNIT_1 = UD60x18.wrap(uHALF_UNIT_1);

/// @dev $log_2(10)$ as a UD60x18 number.
uint256 constant uLOG2_10_1 = 3_321928094887362347;
UD60x18 constant LOG2_10_1 = UD60x18.wrap(uLOG2_10_1);

/// @dev $log_2(e)$ as a UD60x18 number.
uint256 constant uLOG2_E_1 = 1_442695040888963407;
UD60x18 constant LOG2_E_1 = UD60x18.wrap(uLOG2_E_1);

/// @dev The maximum value a UD60x18 number can have.
uint256 constant uMAX_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_584007913129639935;
UD60x18 constant MAX_UD60x18 = UD60x18.wrap(uMAX_UD60x18);

/// @dev The maximum whole value a UD60x18 number can have.
uint256 constant uMAX_WHOLE_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_000000000000000000;
UD60x18 constant MAX_WHOLE_UD60x18 = UD60x18.wrap(uMAX_WHOLE_UD60x18);

/// @dev PI as a UD60x18 number.
UD60x18 constant PI_5 = UD60x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD60x18.
uint256 constant uUNIT_5 = 1e18;
UD60x18 constant UNIT_6 = UD60x18.wrap(uUNIT_5);

/// @dev The unit number squared.
uint256 constant uUNIT_SQUARED_1 = 1e36;
UD60x18 constant UNIT_SQUARED_1 = UD60x18.wrap(uUNIT_SQUARED_1);

/// @dev Zero as a UD60x18 number.
UD60x18 constant ZERO_1 = UD60x18.wrap(0);

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Errors.sol

/// @notice Thrown when ceiling a number overflows UD60x18.
error PRBMath_UD60x18_Ceil_Overflow(UD60x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows UD60x18.
error PRBMath_UD60x18_Convert_Overflow(uint256 x);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_UD60x18_Exp_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_UD60x18_Exp2_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows UD60x18.
error PRBMath_UD60x18_Gm_Overflow(UD60x18 x, UD60x18 y);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD1x18.
error PRBMath_UD60x18_IntoSD1x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD21x18.
error PRBMath_UD60x18_IntoSD21x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD59x18.
error PRBMath_UD60x18_IntoSD59x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD2x18.
error PRBMath_UD60x18_IntoUD2x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD21x18.
error PRBMath_UD60x18_IntoUD21x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint128.
error PRBMath_UD60x18_IntoUint128_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint40.
error PRBMath_UD60x18_IntoUint40_Overflow(UD60x18 x);

/// @notice Thrown when taking the logarithm of a number less than UNIT.
error PRBMath_UD60x18_Log_InputTooSmall(UD60x18 x);

/// @notice Thrown when calculating the square root overflows UD60x18.
error PRBMath_UD60x18_Sqrt_Overflow(UD60x18 x);

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Helpers.sol

/// @notice Implements the checked addition operation (+) in the UD60x18 type.
function add_2(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() + y.unwrap_5());
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and2_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() & y.unwrap_5());
}

/// @notice Implements the equal operation (==) in the UD60x18 type.
function eq_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() == y.unwrap_5();
}

/// @notice Implements the greater than operation (>) in the UD60x18 type.
function gt_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() > y.unwrap_5();
}

/// @notice Implements the greater than or equal to operation (>=) in the UD60x18 type.
function gte_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() >= y.unwrap_5();
}

/// @notice Implements a zero comparison check function in the UD60x18 type.
function isZero_1(UD60x18 x) pure returns (bool result) {
    // This wouldn't work if x could be negative.
    result = x.unwrap_5() == 0;
}

/// @notice Implements the left shift operation (<<) in the UD60x18 type.
function lshift_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() << bits);
}

/// @notice Implements the lower than operation (<) in the UD60x18 type.
function lt_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() < y.unwrap_5();
}

/// @notice Implements the lower than or equal to operation (<=) in the UD60x18 type.
function lte_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() <= y.unwrap_5();
}

/// @notice Implements the checked modulo operation (%) in the UD60x18 type.
function mod_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() % y.unwrap_5());
}

/// @notice Implements the not equal operation (!=) in the UD60x18 type.
function neq_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() != y.unwrap_5();
}

/// @notice Implements the NOT (~) bitwise operation in the UD60x18 type.
function not_1(UD60x18 x) pure returns (UD60x18 result) {
    result = wrap_5(~x.unwrap_5());
}

/// @notice Implements the OR (|) bitwise operation in the UD60x18 type.
function or_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() | y.unwrap_5());
}

/// @notice Implements the right shift operation (>>) in the UD60x18 type.
function rshift_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the UD60x18 type.
function sub_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() - y.unwrap_5());
}

/// @notice Implements the unchecked addition operation (+) in the UD60x18 type.
function uncheckedAdd_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(x.unwrap_5() + y.unwrap_5());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the UD60x18 type.
function uncheckedSub_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(x.unwrap_5() - y.unwrap_5());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the UD60x18 type.
function xor_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() ^ y.unwrap_5());
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Math.sol

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the arithmetic average of x and y using the following formula:
///
/// $$
/// avg(x, y) = (x & y) + ((xUint ^ yUint) / 2)
/// $$
///
/// In English, this is what this formula does:
///
/// 1. AND x and y.
/// 2. Calculate half of XOR x and y.
/// 3. Add the two results together.
///
/// This technique is known as SWAR, which stands for "SIMD within a register". You can read more about it here:
/// https://devblogs.microsoft.com/oldnewthing/20220207-00/?p=106223
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The arithmetic average as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();
    unchecked {
        result = wrap_5((xUint & yUint) + ((xUint ^ yUint) >> 1));
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev This is optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≤ MAX_WHOLE_UD60x18
///
/// @param x The UD60x18 number to ceil.
/// @return result The smallest whole number greater than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    if (xUint > uMAX_WHOLE_UD60x18) {
        revert PRBMath_UD60x18_Ceil_Overflow(x);
    }

    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT_5)

        // Equivalent to `UNIT - remainder`.
        let delta := sub(uUNIT_5, remainder)

        // Equivalent to `x + remainder > 0 ? delta : 0`.
        result := add(x, mul(delta, gt(remainder, 0)))
    }
}

/// @notice Divides two UD60x18 numbers, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @param x The numerator as a UD60x18 number.
/// @param y The denominator as a UD60x18 number.
/// @return result The quotient as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function div_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(mulDiv(x.unwrap_5(), uUNIT_5, y.unwrap_5()));
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Requirements:
/// - x ≤ 133_084258667509499440
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xUint > uEXP_MAX_INPUT_1) {
        revert PRBMath_UD60x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        uint256 doubleUnitProduct = xUint * uLOG2_E_1;
        result = exp2_2(wrap_5(doubleUnitProduct / uUNIT_5));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method.
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693
///
/// Requirements:
/// - x < 192e18
/// - The result must fit in UD60x18.
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2_2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
    if (xUint > uEXP2_MAX_INPUT_1) {
        revert PRBMath_UD60x18_Exp2_InputTooBig(x);
    }

    // Convert x to the 192.64-bit fixed-point format.
    uint256 x_192x64 = (xUint << 64) / uUNIT_5;

    // Pass x to the {Common.exp2} function, which uses the 192.64-bit fixed-point number representation.
    result = wrap_5(exp2_0(x_192x64));
}

/// @notice Yields the greatest whole number less than or equal to x.
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
/// @param x The UD60x18 number to floor.
/// @return result The greatest whole number less than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor_1(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT_5)

        // Equivalent to `x - remainder > 0 ? remainder : 0)`.
        result := sub(x, mul(remainder, gt(remainder, 0)))
    }
}

/// @notice Yields the excess beyond the floor of x using the odd function definition.
/// @dev See https://en.wikipedia.org/wiki/Fractional_part.
/// @param x The UD60x18 number to get the fractional part of.
/// @return result The fractional part of x as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function frac_1(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        result := mod(x, uUNIT_5)
    }
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$, rounding down.
///
/// @dev Requirements:
/// - x * y must fit in UD60x18.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();
    if (xUint == 0 || yUint == 0) {
        return ZERO_1;
    }

    unchecked {
        // Checking for overflow this way is faster than letting Solidity do it.
        uint256 xyUint = xUint * yUint;
        if (xyUint / xUint != yUint) {
            revert PRBMath_UD60x18_Gm_Overflow(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        result = wrap_5(sqrt_0(xyUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The UD60x18 number for which to calculate the inverse.
/// @return result The inverse as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv_1(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(uUNIT_SQUARED_1 / x.unwrap_5());
    }
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln_1(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
        // {log2} can return is ~196_205294292027477728.
        result = wrap_5((log2_1(x).unwrap_5() * uUNIT_5) / uLOG2_E_1);
    }
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    if (xUint < uUNIT_5) {
        revert PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this assembly block is the standard multiplication operation, not {UD60x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT_5, sub(0, 18)) }
        case 10 { result := mul(uUNIT_5, sub(1, 18)) }
        case 100 { result := mul(uUNIT_5, sub(2, 18)) }
        case 1000 { result := mul(uUNIT_5, sub(3, 18)) }
        case 10000 { result := mul(uUNIT_5, sub(4, 18)) }
        case 100000 { result := mul(uUNIT_5, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT_5, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT_5, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT_5, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT_5, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT_5, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT_5, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT_5, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT_5, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT_5, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT_5, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT_5, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT_5, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT_5 }
        case 100000000000000000000 { result := mul(uUNIT_5, 2) }
        case 1000000000000000000000 { result := mul(uUNIT_5, 3) }
        case 10000000000000000000000 { result := mul(uUNIT_5, 4) }
        case 100000000000000000000000 { result := mul(uUNIT_5, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT_5, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT_5, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT_5, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT_5, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT_5, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT_5, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT_5, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT_5, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT_5, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT_5, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT_5, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT_5, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT_5, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT_5, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT_5, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT_5, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT_5, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT_5, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 58) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 59) }
        default { result := uMAX_UD60x18 }
    }

    if (result.unwrap_5() == uMAX_UD60x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap_5((log2_1(x).unwrap_5() * uUNIT_5) / uLOG2_10_1);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x ≥ UNIT
///
/// @param x The UD60x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    if (xUint < uUNIT_5) {
        revert PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    unchecked {
        // Calculate the integer part of the logarithm.
        uint256 n = msb(xUint / uUNIT_5);

        // This is the integer part of the logarithm as a UD60x18 number. The operation can't overflow because n
        // n is at most 255 and UNIT is 1e18.
        uint256 resultUint = n * uUNIT_5;

        // Calculate $y = x * 2^{-n}$.
        uint256 y = xUint >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT_5) {
            return wrap_5(resultUint);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        uint256 DOUBLE_UNIT = 2e18;
        for (uint256 delta = uHALF_UNIT_1; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT_5;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultUint += delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        result = wrap_5(resultUint);
    }
}

/// @notice Multiplies two UD60x18 numbers together, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @dev See the documentation in {Common.mulDiv18}.
/// @param x The multiplicand as a UD60x18 number.
/// @param y The multiplier as a UD60x18 number.
/// @return result The product as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(mulDiv18(x.unwrap_5(), y.unwrap_5()));
}

/// @notice Raises x to the power of y.
///
/// For $1 \leq x \leq \infty$, the following standard formula is used:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// For $0 \leq x \lt 1$, since the unsigned {log2} is undefined, an equivalent formula is used:
///
/// $$
/// i = \frac{1}{x}
/// w = 2^{log_2{i} * y}
/// x^y = \frac{1}{w}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2} and {mul}.
/// - Returns `UNIT` for 0^0.
/// - It may not perform well with very small values of x. Consider using SD59x18 as an alternative.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xUint == 0) {
        return yUint == 0 ? UNIT_6 : ZERO_1;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xUint == uUNIT_5) {
        return UNIT_6;
    }

    // If y is zero, the result is always `UNIT`.
    if (yUint == 0) {
        return UNIT_6;
    }
    // If y is `UNIT`, the result is always x.
    else if (yUint == uUNIT_5) {
        return x;
    }

    // If x is > UNIT, use the standard formula.
    if (xUint > uUNIT_5) {
        result = exp2_2(mul_1(log2_1(x), y));
    }
    // Conversely, if x < UNIT, use the equivalent formula.
    else {
        UD60x18 i = wrap_5(uUNIT_SQUARED_1 / xUint);
        UD60x18 w = exp2_2(mul_1(log2_1(i), y));
        result = wrap_5(uUNIT_SQUARED_1 / w.unwrap_5());
    }
}

/// @notice Raises x (a UD60x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - The result must fit in UD60x18.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu_1(UD60x18 x, uint256 y) pure returns (UD60x18 result) {
    // Calculate the first iteration of the loop in advance.
    uint256 xUint = x.unwrap_5();
    uint256 resultUint = y & 1 > 0 ? xUint : uUNIT_5;

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    for (y >>= 1; y > 0; y >>= 1) {
        xUint = mulDiv18(xUint, xUint);

        // Equivalent to `y % 2 == 1`.
        if (y & 1 > 0) {
            resultUint = mulDiv18(resultUint, xUint);
        }
    }
    result = wrap_5(resultUint);
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x ≤ MAX_UD60x18 / UNIT
///
/// @param x The UD60x18 number for which to calculate the square root.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt_2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    unchecked {
        if (xUint > uMAX_UD60x18 / uUNIT_5) {
            revert PRBMath_UD60x18_Sqrt_Overflow(x);
        }
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two UD60x18 numbers.
        // In this case, the two numbers are both the square root.
        result = wrap_5(sqrt_0(xUint * uUNIT_5));
    }
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/ValueType.sol

/// @notice The unsigned 60.18-decimal fixed-point number representation, which can have up to 60 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the Solidity type uint256.
/// @dev The value type is defined here so it can be imported in all other files.
type UD60x18 is uint256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD1x18_1,
    intoSD21x18_1,
    intoSD59x18_4,
    intoUD2x18_1,
    intoUD21x18_1,
    intoUint128_5,
    intoUint256_5,
    intoUint40_5,
    unwrap_5
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    avg_1,
    ceil_1,
    div_1,
    exp_1,
    exp2_2,
    floor_1,
    frac_1,
    gm_1,
    inv_1,
    ln_1,
    log10_1,
    log2_1,
    mul_1,
    pow_1,
    powu_1,
    sqrt_2
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    add_2,
    and_1,
    eq_1,
    gt_1,
    gte_1,
    isZero_1,
    lshift_1,
    lt_1,
    lte_1,
    mod_1,
    neq_1,
    not_1,
    or_1,
    rshift_1,
    sub_1,
    uncheckedAdd_1,
    uncheckedSub_1,
    xor_1
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the UD60x18 type.
using {
    add_2 as +,
    and2_1 as &,
    div_1 as /,
    eq_1 as ==,
    gt_1 as >,
    gte_1 as >=,
    lt_1 as <,
    lte_1 as <=,
    or_1 as |,
    mod_1 as %,
    mul_1 as *,
    neq_1 as !=,
    not_1 as ~,
    sub_1 as -,
    xor_1 as ^
} for UD60x18 global;

// node_modules/@summerfi/dependencies/lib/prb-math/src/ud60x18/Conversions.sol

/// @notice Converts a UD60x18 number to a simple integer by dividing it by `UNIT`.
/// @dev The result is rounded toward zero.
/// @param x The UD60x18 number to convert.
/// @return result The same number in basic integer form.
function convert_1(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x) / uUNIT_5;
}

/// @notice Converts a simple integer to UD60x18 by multiplying it by `UNIT`.
///
/// @dev Requirements:
/// - x ≤ MAX_UD60x18 / UNIT
///
/// @param x The basic integer to convert.
/// @return result The same number converted to UD60x18.
function convert_0(uint256 x) pure returns (UD60x18 result) {
    if (x > uMAX_UD60x18 / uUNIT_5) {
        revert PRBMath_UD60x18_Convert_Overflow(x);
    }
    unchecked {
        result = UD60x18.wrap(x * uUNIT_5);
    }
}

// node_modules/@summerfi/dependencies/lib/prb-math/src/UD60x18.sol

/*

██████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██████╔╝██████╔╝██████╔╝██╔████╔██║███████║   ██║   ███████║
██╔═══╝ ██╔══██╗██╔══██╗██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║     ██║  ██║██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

██╗   ██╗██████╗  ██████╗  ██████╗ ██╗  ██╗ ██╗ █████╗
██║   ██║██╔══██╗██╔════╝ ██╔═████╗╚██╗██╔╝███║██╔══██╗
██║   ██║██║  ██║███████╗ ██║██╔██║ ╚███╔╝ ╚██║╚█████╔╝
██║   ██║██║  ██║██╔═══██╗████╔╝██║ ██╔██╗  ██║██╔══██╗
╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝██╔╝ ██╗ ██║╚█████╔╝
 ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═╝ ╚════╝

*/

// node_modules/@summerfi/dutch-auction/src/DutchAuctionMath.sol

/**
 * @title Dutch Auction Math Library
 * @author halaprix
 * @notice This library provides mathematical functions for Dutch auction calculations with support for various token
 * decimals
 * @dev Uses PRBMath library for precise calculations with fixed-point numbers and TokenLibrary for decimal conversions
 */
library DutchAuctionMath {
    using TokenLibrary for uint256;

    /**
     * @notice Calculates the current price based on linear decay
     * @dev The price decreases linearly from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param priceDecimals The number of decimals for the price values
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on linear decay
     *
     * @dev Process:
     * 1. Convert start and end prices to 18 decimals for precise calculation
     * 2. Calculate the price difference and decay amount using 18 decimal precision
     * 3. Subtract the decay amount from the start price
     * 4. Convert the result back to the desired number of decimals
     */
    function linearDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 priceDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 startPriceWei = startPrice.toWei(priceDecimals);
        uint256 endPriceWei = endPrice.toWei(priceDecimals);

        UD60x18 priceDifference = ud(startPriceWei - endPriceWei);
        UD60x18 timeElapsedUD = convert_0(timeElapsed);
        UD60x18 totalDurationUD = convert_0(totalDuration);

        UD60x18 decayedDifference = priceDifference.mul_1(timeElapsedUD).div_1(
            totalDurationUD
        );

        uint256 currentPriceWei = startPriceWei - unwrap_5(decayedDifference);
        return currentPriceWei.fromWei(resultDecimals);
    }

    /**
     * @notice Calculates the current price based on quadratic decay
     * @dev The price decreases quadratically from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param priceDecimals The number of decimals for the price values
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on quadratic decay
     *
     * @dev Process:
     * 1. Convert start and end prices to 18 decimals for precise calculation
     * 2. Calculate the remaining time and its square
     * 3. Calculate the decay amount using the formula: priceDifference * (remainingTime^2 / totalDuration^2)
     * 4. Add the decay amount to the end price
     * 5. Convert the result back to the desired number of decimals
     */
    function quadraticDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 priceDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 startPriceWei = startPrice.toWei(priceDecimals);
        uint256 endPriceWei = endPrice.toWei(priceDecimals);

        UD60x18 priceDifference = ud(startPriceWei - endPriceWei);
        UD60x18 timeRemaining = convert_0(totalDuration - timeElapsed);
        UD60x18 totalDurationUD = convert_0(totalDuration);

        // Calculate (totalDuration - timeElapsed) ** 2
        UD60x18 timeRemainingSquared = timeRemaining.powu_1(2);

        // Calculate totalDuration ** 2
        UD60x18 totalDurationSquared = totalDurationUD.powu_1(2);

        // Calculate (priceDifference * (totalDuration - timeElapsed) ** 2) / totalDuration ** 2
        UD60x18 decayedDifference = priceDifference
            .mul_1(timeRemainingSquared)
            .div_1(totalDurationSquared);

        uint256 currentPriceWei = endPriceWei + unwrap_5(decayedDifference);
        return currentPriceWei.fromWei(resultDecimals);
    }

    /**
     * @notice Calculates the total cost for a given price and amount, considering different token decimals
     * @dev Converts values to 18 decimals using TokenLibrary, performs the calculation, and converts the result back
     * @param price The price per unit
     * @param amount The number of units
     * @param priceDecimals The number of decimals for the price token
     * @param amountDecimals The number of decimals for the amount token
     * @param resultDecimals The desired number of decimals for the result
     * @return The total cost
     *
     * @dev Process:
     * 1. Convert both price and amount to 18 decimals for precise calculation
     * 2. Multiply the converted price and amount using PRBMath's high-precision operations
     * 3. Convert the result back to the desired number of decimals
     *
     * @dev Note: This function ensures high precision by performing all intermediate calculations
     * with 18 decimal places, regardless of the input or output decimal specifications.
     */
    function calculateTotalCost(
        uint256 price,
        uint256 amount,
        uint8 priceDecimals,
        uint8 amountDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 priceWei = price.toWei(priceDecimals);
        uint256 amountWei = amount.toWei(amountDecimals);

        UD60x18 resultUD = ud(priceWei).mul_1(ud(amountWei));

        return unwrap_5(resultUD).fromWei(resultDecimals);
    }
}

// node_modules/@summerfi/dutch-auction/src/DecayFunctions.sol

/**
 * @title DecayFunctions Library
 * @author halaprix
 * @notice This library provides functions to calculate price decay for Dutch auctions
 * @dev Implements both linear and quadratic decay functions
 */
library DecayFunctions {
    /**
     * @notice Enum representing the types of decay functions available
     * @dev Used to select between linear and quadratic decay in calculations
     */
    enum DecayType {
        Linear,
        Quadratic
    }

    /**
     * @notice Thrown when the decay type is invalid
     */
    error InvalidDecayType();

    /**
     * @notice Calculates the current price based on the specified decay type
     * @dev This function acts as a wrapper for the specific decay calculations in DutchAuctionMath
     * @param decayType The type of decay function to use (Linear or Quadratic)
     * @param startPrice The starting price of the auction (in token units)
     * @param endPrice The ending price of the auction (in token units)
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param decimals The number of decimals for the input prices
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on the specified decay function
     *
     * @dev Calculation process:
     * 1. Check if the auction has ended (timeElapsed >= totalDuration)
     * 2. If the auction has ended, return the end price
     * 3. If the auction is still active, calculate the current price using the specified decay function
     * 4. For Linear decay, use DutchAuctionMath.linearDecay
     * 5. For Quadratic decay, use DutchAuctionMath.quadraticDecay
     *
     * @dev Note on precision:
     * - All price calculations are performed with high precision using the DutchAuctionMath library
     * - The input prices and result can have different decimal places, allowing for flexible token configurations
     *
     * @dev Usage:
     * - This function should be called periodically to get the current price of the auctioned item
     * - It can handle different token decimals for both input and output, making it versatile for various token pairs
     */
    function calculateDecay(
        DecayType decayType,
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 decimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        // Check if the auction has ended
        if (timeElapsed >= totalDuration) {
            return endPrice;
        }

        // Calculate the current price based on the specified decay type
        if (decayType == DecayType.Linear) {
            return
                DutchAuctionMath.linearDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration,
                    decimals,
                    resultDecimals
                );
        } else if (decayType == DecayType.Quadratic) {
            return
                DutchAuctionMath.quadraticDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration,
                    decimals,
                    resultDecimals
                );
        } else {
            revert InvalidDecayType();
        }
    }
}

// src/interfaces/IFleetCommander.sol

/**
 * @title IFleetCommander Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommander is
    IERC4626,
    IFleetCommanderEvents,
    IFleetCommanderErrors,
    IFleetCommanderConfigProvider
{
    /**
     * @notice Returns the total assets that are currently withdrawable from the FleetCommander.
     * @dev If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)
     * @return uint256 The total amount of assets that can be withdrawn.
     */
    function withdrawableTotalAssets() external view returns (uint256);

    /**
     * @notice Returns the total assets that are managed the FleetCommander.
     * @dev If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)
     * @return uint256 The total amount of assets that can be withdrawn.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, directly from Buffer.
     * @param owner The address of the owner of the assets
     * @return uint256 The maximum amount that can be withdrawn.
     */
    function maxBufferWithdraw(address owner) external view returns (uint256);

    /**
     * @notice Returns the maximum amount of the underlying asset that can be redeemed from the owner balance in the
     * Vault, directly from Buffer.
     * @param owner The address of the owner of the assets
     * @return uint256 The maximum amount that can be redeemed.
     */
    function maxBufferRedeem(address owner) external view returns (uint256);

    /* FUNCTIONS - PUBLIC - USER */
    /**
     * @notice Deposits a specified amount of assets into the contract for a given receiver.
     * @param assets The amount of assets to be deposited.
     * @param receiver The address of the receiver who will receive the deposited assets.
     * @param referralCode An optional referral code that can be used for tracking or rewards.
     */
    function deposit(
        uint256 assets,
        address receiver,
        bytes memory referralCode
    ) external returns (uint256);

    /**
     * @notice Forces a withdrawal of assets from the FleetCommander
     * @param assets The amount of assets to forcefully withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return shares The amount of shares redeemed
     */
    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Withdraws a specified amount of assets from the FleetCommander
     * @dev This function first attempts to withdraw from the buffer. If the buffer doesn't have enough assets,
     *      it will withdraw from the arks. It also handles the case where the maximum possible amount is requested.
     * @param assets The amount of assets to withdraw. If set to type(uint256).max, it will withdraw the maximum
     * possible amount.
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the shares
     * @return shares The number of shares burned in exchange for the withdrawn assets
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Redeems a specified amount of shares from the FleetCommander
     * @dev This function first attempts to redeem from the buffer. If the buffer doesn't have enough assets,
     *      it will redeem from the arks. It also handles the case where the maximum possible amount is requested.
     * @param shares The number of shares to redeem. If set to type(uint256).max, it will redeem all shares owned by the
     * owner.
     * @param receiver The address that will receive the redeemed assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets received in exchange for the redeemed shares
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Redeems shares for assets from the FleetCommander
     * @param shares The amount of shares to redeem
     * @param receiver  The address that will receive the assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets forcefully withdrawn
     */
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Redeems shares for assets directly from the Buffer
     * @param shares The amount of shares to redeem
     * @param receiver The address that will receive the assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets redeemed
     */
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Forces a withdrawal of assets directly from the Buffer
     * @param assets The amount of assets to withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return shares The amount of shares redeemed
     */
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Accrues and distributes tips
     * @return uint256 The amount of tips accrued
     */
    function tip() external returns (uint256);

    /**
     * @notice Rebalances the assets across Arks, including buffer adjustments
     * @param data Array of RebalanceData structs
     * @dev RebalanceData struct contains:
     *      - fromArk: The address of the Ark to move assets from
     *      - toArk: The address of the Ark to move assets to
     *      - amount: The amount of assets to move
     *      - boardData: Additional data for the board operation
     *      - disembarkData: Additional data for the disembark operation
     * @dev Using type(uint256).max as the amount will move all assets from the fromArk to the toArk
     * @dev For standard rebalancing:
     *      - Operations cannot involve the buffer Ark directly
     * @dev For buffer adjustments:
     *      - type(uint256).max is only allowed when moving TO the buffer
     *      - When withdrawing FROM buffer, total amount cannot reduce balance below minFundsBufferBalance
     * @dev The number of operations in a single rebalance call is limited to MAX_REBALANCE_OPERATIONS
     * @dev Rebalance is subject to a cooldown period between calls
     * @dev Only callable by accounts with the Keeper role
     */
    function rebalance(RebalanceData[] calldata data) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Sets a new tip rate for the FleetCommander
     * @dev Only callable by the governor
     * @dev The tip rate is set as a Percentage. Percentages use 18 decimals of precision
     *      For example, for a 5% rate, you'd pass 5 * 1e18 (5 000 000 000 000 000 000)
     * @param newTipRate The new tip rate as a Percentage
     */
    function setTipRate(Percentage newTipRate) external;

    /**
     * @notice Updates the rebalance cooldown period
     * @param newCooldown The new cooldown period in seconds
     */
    function updateRebalanceCooldown(uint256 newCooldown) external;

    /**
     * @notice Forces a rebalance operation
     * @param data Array of typed rebalance data struct
     * @dev has no cooldown enforced but only callable by privileged role
     */
    function forceRebalance(RebalanceData[] calldata data) external;

    /**
     * @notice Pauses the FleetCommander
     * @dev This function is used to pause the FleetCommander in case of critical issues or emergencies
     * @dev Only callable by the guardian or governor
     */
    function pause() external;

    /**
     * @notice Unpauses the FleetCommander
     * @dev This function is used to resume normal operations after a pause
     * @dev Only callable by the guardian or governor
     */
    function unpause() external;
}

// src/types/CommonAuctionTypes.sol

/**
 * @title BaseAuctionParameters
 * @notice Struct containing default parameters for Dutch auctions
 * @dev This struct is used to configure the default settings for Dutch auctions in the protocol
 */
struct BaseAuctionParameters {
    /**
     * @notice The duration of the auction in seconds
     * @dev This value determines how long the auction will run before it can be finalized
     */
    uint40 duration;
    /**
     * @notice The starting price of the auction in payment token decimals
     * @dev This is the highest price at which the auction begins
     */
    uint256 startPrice;
    /**
     * @notice The ending price of the auction in payment token decimals
     * @dev This is the lowest price the auction can reach. The auction ends when this price is hit or when duration is
     * reached
     */
    uint256 endPrice;
    /**
     * @notice The percentage of auctioned tokens to be given as a reward to the auction initiator (kicker)
     * @dev This is represented as a Percentage type, where 100 * 1e18 = 100%
     * @dev This value is used to incentivize the auction initiator to kick off the auction
     * @dev The reward is calculated as a percentage of the total auctioned tokens
     */
    Percentage kickerRewardPercentage;
    /**
     * @notice The type of price decay function to use for the auction
     * @dev This determines how the price changes over time during the auction
     * @dev See DecayFunctions.sol for more information
     */
    DecayFunctions.DecayType decayType;
}

// src/events/IAuctionManagerBaseEvents.sol

interface IAuctionManagerBaseEvents {
    /**
     * @notice Emitted when the auction configuration is updated
     * @param newConfig The new auction configuration
     */
    event AuctionDefaultParametersUpdated(BaseAuctionParameters newConfig);
}

// src/events/IRaftEvents.sol

/**
 * @title IRaftEvents
 * @notice Interface defining events emitted by the Raft contract
 */
interface IRaftEvents {
    /**
     * @notice Emitted when a new auction is started for an Ark's reward token
     * @param auctionId The unique identifier of the auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token being auctioned
     * @param amount The amount of tokens being auctioned
     */
    event ArkRewardTokenAuctionStarted(
        uint256 auctionId,
        address ark,
        address rewardToken,
        uint256 amount
    );

    /**
     * @notice Emitted when rewards are harvested from an Ark
     * @param ark The address of the Ark contract
     * @param rewardTokens The addresses of the harvested reward tokens
     * @param rewardAmounts The amounts of the harvested reward tokens
     */
    event ArkHarvested(
        address indexed ark,
        address[] indexed rewardTokens,
        uint256[] indexed rewardAmounts
    );

    /**
     * @notice Emitted when auctioned rewards are boarded back into an Ark
     * @param ark The address of the Ark contract
     * @param fromRewardToken The address of the original reward token
     * @param toFleetToken The address of the token boarded into the Ark
     * @param amountReboarded The amount of tokens reboarded
     */
    event RewardBoarded(
        address indexed ark,
        address indexed fromRewardToken,
        address indexed toFleetToken,
        uint256 amountReboarded
    );

    /**
     * @notice Emitted when a sweepable token is set for an Ark
     * @param ark The address of the Ark contract
     * @param token The address of the token
     * @param isSweepable Whether the token is sweepable
     */
    event SweepableTokenSet(
        address indexed ark,
        address indexed token,
        bool isSweepable
    );

    /**
     * @notice Emitted when auction parameters are set for an Ark's reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @param parameters The auction parameters
     */
    event ArkAuctionParametersSet(
        address indexed ark,
        address indexed rewardToken,
        BaseAuctionParameters parameters
    );
}

// node_modules/@summerfi/dutch-auction/src/DutchAuctionLibrary.sol

/**
 * @title Dutch Auction Library
 * @author halaprix
 * @notice This library implements core functionality for running Dutch auctions
 * @dev This library is designed to be used by a contract managing multiple auctions
 *
 * @dev Auction Mechanics:
 *
 * 1. Auction Lifecycle:
 *    - Creation: An auction is created with specified parameters (tokens, duration, prices, etc.).
 *    - Active Period: The auction is active from its start time until its end time or until all tokens are sold.
 *    - Finalization: The auction is finalized either when all tokens are sold or after the end time is reached.
 *
 * 2. Price Movement:
 *    - The price is calculated on-demand based on the current timestamp using a specified decay function.
 *    - It's not updated per block, but rather computed when `getCurrentPrice` is called, using current timestamp.
 *    - This ensures smooth price decay over time, independent of block creation.
 *
 * 3. Buying Limits:
 *    - Users can buy any amount of tokens up to the remaining amount in the auction.
 *    - There's no minimum purchase amount enforced by the contract.
 *
 * 4. Price Calculation and Rounding:
 *    - The current price is calculated using the specified decay function (linear or quadratic).
 *    - Rounding is done towards zero (floor) to ensure the contract never overcharges.
 *    - For utmost precision, all calculations use the PRBMath library for fixed-point arithmetic.
 *
 * 5. Token Handling:
 *    - The auctioning contract must be pre-approved to spend the tokens used for payment.
 *    - Tokens should be transferred to the auctioning contract before or during auction creation.
 *    - The contract holds the tokens and transfers them to buyers upon successful purchases.
 *
 * 6. Kicker Reward:
 *    - A portion of the auctioned tokens is set aside as a reward for the auction initiator (kicker).
 *    - This reward is transferred to the kicker immediately upon auction creation.
 *
 * 7. Unsold Tokens:
 *    - Any unsold tokens at the end of the auction are transferred to a specified recipient address.
 *    - This transfer occurs during the finalization of the auction.
 */
library DutchAuctionLibrary {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;
    using TokenLibrary for IERC20;

    /**
     * @notice Struct representing the configuration of a Dutch auction
     * @dev This struct contains all the fixed parameters set at auction creation
     */
    struct AuctionConfig {
        IERC20 auctionToken; // The token being auctioned
        IERC20 paymentToken; // The token used for payment
        uint40 startTime; // The start time of the auction
        uint40 endTime; // The end time of the auction
        uint8 auctionTokenDecimals; // The number of decimals for the auction token
        uint8 paymentTokenDecimals; // The number of decimals for the payment token
        address auctionKicker; // The address that initiated the auction
        address unsoldTokensRecipient; // The address to receive any unsold tokens
        uint40 id; // The unique identifier of the auction
        DecayFunctions.DecayType decayType; // The type of price decay for the auction
        uint256 startPrice; // The starting price of the auctioned token
        uint256 endPrice; // The ending price of the auctioned token
        uint256 totalTokens; // The total number of tokens being auctioned
        uint256 kickerRewardAmount; // The amount of tokens reserved as kicker reward
    }

    /**
     * @notice Struct representing the dynamic state of a Dutch auction
     * @dev This struct contains all the variables that change during the auction's lifecycle
     */
    struct AuctionState {
        uint256 remainingTokens; // The number of tokens remaining to be sold
        bool isFinalized; // Whether the auction has been finalized
    }

    /**
     * @notice Struct representing a complete Dutch auction
     * @dev This struct combines the fixed configuration and dynamic state of an auction
     */
    struct Auction {
        AuctionConfig config;
        AuctionState state;
    }

    /**
     * @notice Struct containing parameters for creating a new auction
     * @dev This struct is used as an input to the createAuction function
     */
    struct AuctionParams {
        uint256 auctionId; // The unique identifier for the new auction
        IERC20 auctionToken; // The token being auctioned
        IERC20 paymentToken; // The token used for payment
        uint40 duration; // The duration of the auction in seconds
        uint256 startPrice; // The starting price of the auctioned token
        uint256 endPrice; // The ending price of the auctioned token
        uint256 totalTokens; // The total number of tokens to be auctioned
        Percentage kickerRewardPercentage; // The percentage of tokens to be given as kicker reward
        address kicker; // The address of the auction initiator
        address unsoldTokensRecipient; // The address to receive any unsold tokens
        DecayFunctions.DecayType decayType; // The type of price decay for the auction
    }

    /**
     * @notice Creates a new Dutch auction
     * @dev This function initializes a new auction with the given parameters
     * @param params The parameters for the new auction
     * @return auction The created Auction struct
     */
    function createAuction(
        AuctionParams memory params
    ) external returns (Auction memory auction) {
        if (params.duration == 0) revert DutchAuctionErrors.InvalidDuration();
        if (params.startPrice <= params.endPrice) {
            revert DutchAuctionErrors.InvalidPrices();
        }
        if (params.totalTokens == 0) {
            revert DutchAuctionErrors.InvalidTokenAmount();
        }

        if (
            !PercentageUtils.isPercentageInRange(params.kickerRewardPercentage)
        ) {
            revert DutchAuctionErrors.InvalidKickerRewardPercentage();
        }
        if (address(params.auctionToken) == address(0)) {
            revert DutchAuctionErrors.InvalidAuctionToken();
        }
        if (address(params.paymentToken) == address(0)) {
            revert DutchAuctionErrors.InvalidPaymentToken();
        }

        uint256 kickerRewardAmount = params.totalTokens.applyPercentage(
            params.kickerRewardPercentage
        );
        uint256 auctionedTokens = params.totalTokens - kickerRewardAmount;

        // Set up AuctionConfig
        auction.config = AuctionConfig({
            id: uint40(params.auctionId),
            auctionToken: params.auctionToken,
            paymentToken: params.paymentToken,
            auctionTokenDecimals: params.auctionToken.getDecimals(),
            paymentTokenDecimals: params.paymentToken.getDecimals(),
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + params.duration),
            startPrice: params.startPrice,
            endPrice: params.endPrice,
            totalTokens: auctionedTokens,
            auctionKicker: params.kicker,
            kickerRewardAmount: kickerRewardAmount,
            unsoldTokensRecipient: params.unsoldTokensRecipient,
            decayType: params.decayType
        });

        // Set up AuctionState
        auction.state = AuctionState({
            remainingTokens: auctionedTokens,
            isFinalized: false
        });

        _claimKickerReward(auction);

        emit DutchAuctionEvents.AuctionCreated(
            params.auctionId,
            msg.sender,
            auctionedTokens,
            kickerRewardAmount
        );
    }

    /**
     * @notice Calculates the current price of tokens in an ongoing auction
     * @dev This function computes the price based on the elapsed time and decay function
     * @param auction The Auction struct
     * @return The current price of tokens in the auction
     */
    function getCurrentPrice(
        Auction memory auction
    ) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - auction.config.startTime;
        uint256 totalDuration = auction.config.endTime -
            auction.config.startTime;

        return
            DecayFunctions.calculateDecay(
                auction.config.decayType,
                auction.config.startPrice,
                auction.config.endPrice,
                timeElapsed,
                totalDuration,
                auction.config.paymentTokenDecimals,
                auction.config.paymentTokenDecimals
            );
    }

    /**
     * @notice Allows a user to purchase tokens from an ongoing auction
     * @dev This function handles the token purchase, including price calculation and token transfers
     * @param auction The storage pointer to the auction
     * @param _amount The number of tokens to purchase
     */
    function buyTokens(
        Auction storage auction,
        uint256 _amount
    ) internal returns (uint256 totalCost) {
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert DutchAuctionErrors.AuctionNotFound();
        }
        if (auction.state.isFinalized) {
            revert DutchAuctionErrors.AuctionAlreadyFinalized(
                auction.config.id
            );
        }
        if (block.timestamp >= auction.config.endTime) {
            revert DutchAuctionErrors.AuctionNotActive(auction.config.id);
        }
        if (_amount > auction.state.remainingTokens) {
            revert DutchAuctionErrors.InsufficientTokensAvailable();
        }

        uint256 currentPrice = getCurrentPrice(auction);

        totalCost = DutchAuctionMath.calculateTotalCost(
            currentPrice,
            _amount,
            auction.config.paymentTokenDecimals,
            auction.config.auctionTokenDecimals,
            auction.config.paymentTokenDecimals
        );

        auction.state.remainingTokens -= _amount;

        auction.config.paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalCost
        );
        auction.config.auctionToken.safeTransfer(msg.sender, _amount);

        emit DutchAuctionEvents.TokensPurchased(
            auction.config.id,
            msg.sender,
            _amount,
            currentPrice
        );

        if (auction.state.remainingTokens == 0) {
            _finalizeAuction(auction);
        }
    }

    /**
     * @notice Finalizes an auction after its end time has been reached
     * @dev This function can be called by anyone after the auction end time
     * @param auction The storage pointer to the auction to be finalized
     */
    function finalizeAuction(Auction storage auction) internal {
        if (auction.config.auctionToken == IERC20(address(0))) {
            revert DutchAuctionErrors.AuctionNotFound();
        }
        if (auction.state.isFinalized) {
            revert DutchAuctionErrors.AuctionAlreadyFinalized(
                auction.config.id
            );
        }
        if (block.timestamp < auction.config.endTime) {
            revert DutchAuctionErrors.AuctionNotEnded(auction.config.id);
        }
        _finalizeAuction(auction);
    }

    /**
     * @notice Internal function to handle auction finalization logic
     * @dev This function distributes unsold tokens and marks the auction as finalized
     * @param auction The storage pointer to the auction to be finalized
     */
    function _finalizeAuction(Auction storage auction) internal {
        uint256 soldTokens = auction.config.totalTokens -
            auction.state.remainingTokens;

        auction.state.isFinalized = true;

        if (auction.state.remainingTokens > 0) {
            auction.config.auctionToken.safeTransfer(
                auction.config.unsoldTokensRecipient,
                auction.state.remainingTokens
            );
        }

        emit DutchAuctionEvents.AuctionFinalized(
            auction.config.id,
            soldTokens,
            auction.state.remainingTokens
        );
    }

    /**
     * @notice Claims the kicker reward for the auction
     * @dev Transfers the kicker reward to the kicker's address immediately upon auction creation
     * @param auction The auction to claim the kicker reward from
     */
    function _claimKickerReward(Auction memory auction) internal {
        if (auction.config.kickerRewardAmount == 0) {
            return;
        }
        auction.config.auctionToken.safeTransfer(
            auction.config.auctionKicker,
            auction.config.kickerRewardAmount
        );

        emit DutchAuctionEvents.KickerRewardClaimed(
            auction.config.id,
            auction.config.auctionKicker,
            auction.config.kickerRewardAmount
        );
    }
}

// src/contracts/ArkAccessManaged.sol

/**
 * @title ArkAccessManaged
 * @author SummerFi
 * @notice This contract manages access control for Ark-related operations.
 * @dev Inherits from ProtocolAccessManaged and implements IArkAccessManaged.
 * @custom:see IArkAccessManaged
 */
contract ArkAccessManaged is IArkAccessManaged, ProtocolAccessManaged {
    /**
     * @notice Initializes the ArkAccessManaged contract.
     * @param accessManager The address of the access manager contract.
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}

    /**
     * @notice Checks if the caller is authorized to board funds.
     * @dev This modifier allows the Commander, RAFT contract, or active Arks to proceed.
     * @param commander The address of the FleetCommander contract.
     * @custom:internal-logic
     * - Checks if the caller is the registered commander
     * - If not, checks if the caller is the RAFT contract
     * - If not, checks if the caller is an active Ark in the FleetCommander
     * @custom:effects
     * - Reverts if the caller doesn't have the necessary permissions
     * - Allows the function to proceed if the caller is authorized
     * @custom:security-considerations
     * - Ensures that only authorized entities can board funds
     * - Relies on the correct setup of the FleetCommander and RAFT contracts
     */
    modifier onlyAuthorizedToBoard(address commander) {
        if (commander != _msgSender()) {
            address msgSender = _msgSender();
            bool isRaft = msgSender ==
                IConfigurationManaged(address(this)).raft();

            if (!isRaft) {
                bool isArk = IFleetCommander(commander).isArkActiveOrBufferArk(
                    msgSender
                );
                if (!isArk) {
                    revert CallerIsNotAuthorizedToBoard(msgSender);
                }
            }
        }
        _;
    }

    /**
     * @notice Restricts access to only the RAFT contract.
     * @dev Modifier to check that the caller is the RAFT contract
     * @custom:internal-logic
     * - Retrieves the RAFT address from the ConfigurationManaged contract
     * - Compares the caller's address with the RAFT address
     * @custom:effects
     * - Reverts if the caller is not the RAFT contract
     * - Allows the function to proceed if the caller is the RAFT contract
     * @custom:security-considerations
     * - Ensures that only the RAFT contract can call certain functions
     * - Relies on the correct setup of the ConfigurationManaged contract
     */
    modifier onlyRaft() {
        if (_msgSender() != IConfigurationManaged(address(this)).raft()) {
            revert CallerIsNotRaft(_msgSender());
        }
        _;
    }

    /**
     * @notice Checks if the caller has the Commander role.
     * @dev Internal function to check if the caller has the Commander role
     * @return bool True if the caller has the Commander role, false otherwise
     * @custom:internal-logic
     * - Generates the Commander role identifier for this contract
     * - Checks if the caller has the generated role in the access manager
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Relies on the correct setup of the access manager
     * - Assumes that the Commander role is properly assigned
     */
    function _hasCommanderRole() internal view returns (bool) {
        return
            _accessManager.hasRole(
                generateRole(
                    ContractSpecificRoles.COMMANDER_ROLE,
                    address(this)
                ),
                _msgSender()
            );
    }
}

// src/contracts/AuctionManagerBase.sol

/**
 * @title AuctionManagerBase
 * @notice Base contract for managing Dutch auctions
 * @dev This abstract contract provides core functionality for creating and managing Dutch auctions
 */
abstract contract AuctionManagerBase is IAuctionManagerBaseEvents {
    using SafeERC20 for IERC20;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /// @notice Counter for tracking the current auction ID
    /// @dev Initialized to 0. Incremented before each new auction creation
    uint256 public currentAuctionId;

    /**
     * @notice Initializes the AuctionManagerBase
     */
    constructor() {
        // currentAuctionId is implicitly initialized to 0
    }

    /**
     * @dev Creates a new Dutch auction
     * @param auctionToken The token being auctioned
     * @param paymentToken The token used for payments
     * @param totalTokens The total number of tokens to be auctioned
     * @param unsoldTokensRecipient The address to receive any unsold tokens after the auction
     * @param baseParams The parameters for the auction
     * @return A new Auction struct
     * @custom:internal-logic
     * - Pre-increments currentAuctionId to generate a unique ID (first auction will have ID 1)
     * - Creates an AuctionParams struct using provided parameters
     * - Calls the createAuction function of the DutchAuctionLibrary to initialize the auction
     * @custom:effects
     * - Increments currentAuctionId
     * - Creates and returns a new Auction struct
     * @custom:security-considerations
     * - Ensure that the provided token addresses are valid
     * - Verify that totalTokens is non-zero and matches the actual token balance
     */
    function _createAuctionWithParams(
        IERC20 auctionToken,
        IERC20 paymentToken,
        uint256 totalTokens,
        address unsoldTokensRecipient,
        BaseAuctionParameters memory baseParams
    ) internal returns (DutchAuctionLibrary.Auction memory) {
        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: ++currentAuctionId,
                auctionToken: auctionToken,
                paymentToken: paymentToken,
                duration: baseParams.duration,
                startPrice: baseParams.startPrice,
                endPrice: baseParams.endPrice,
                totalTokens: totalTokens,
                kickerRewardPercentage: baseParams.kickerRewardPercentage,
                kicker: msg.sender,
                unsoldTokensRecipient: unsoldTokensRecipient,
                decayType: baseParams.decayType
            });

        return DutchAuctionLibrary.createAuction(params);
    }

    /**
     * @dev Gets the current price of an ongoing auction
     * @param auction The storage pointer to the auction
     * @return The current price of the auction in payment token decimals
     * @custom:internal-logic
     * - Calls the getCurrentPrice function of the DutchAuctionLibrary
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the auction is ongoing when calling this function
     */
    function _getCurrentPrice(
        DutchAuctionLibrary.Auction storage auction
    ) internal view returns (uint256) {
        return auction.getCurrentPrice();
    }
}

// src/interfaces/IRaft.sol

/**
 * @title IRaft
 * @notice Interface for the Raft contract which manages harvesting, auctioning, and reinvesting of rewards.
 * @dev This interface defines the core functionality for managing rewards from various Arks.
 */
interface IRaft is IRaftEvents, IRaftErrors {
    /**
     * @dev Harvests rewards from the specified Ark and starts an auction for the harvested tokens
     * @param ark The address of the Ark contract to harvest rewards from
     * @param rewardData Additional data required by a protocol to harvest
     * @custom:internal-logic
     * - Harvests rewards from the specified Ark
     * - Starts an auction for each harvested token
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Creates new auctions
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Validate input parameters
     */
    function harvestAndStartAuction(
        address ark,
        bytes calldata rewardData
    ) external;

    /**
     * @dev Harvests rewards from the specified Ark without auctioning or reinvesting
     * @param ark The address of the Ark contract to harvest rewards from
     * @param rewardData Additional data required by a protocol to harvest
     * @custom:internal-logic
     * - Calls the harvest function on the specified Ark
     * - Updates the obtainedTokens mapping with harvested amounts
     * @custom:effects
     * - Updates obtainedTokens mapping
     * @custom:security-considerations
     * - Validate the Ark address
     * - Ensure proper handling of rewardData
     */
    function harvest(address ark, bytes calldata rewardData) external;

    /**
     * @dev Sweeps tokens from the specified Ark and returns them to the caller
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @return sweptTokens The addresses of the tokens that were swept
     * @return sweptAmounts The amounts of the tokens that were swept
     * @custom:internal-logic
     * - Calls the sweep function on the specified Ark
     * - Updates the obtainedTokens mapping with swept amounts
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Transfers swept tokens to the contract
     * @custom:security-considerations
     * - Validate input parameters
     */
    function sweep(
        address ark,
        address[] calldata tokens
    )
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);

    /**
     * @dev Sweeps tokens from the specified Ark and starts an auction for them
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @custom:internal-logic
     * - Sweeps specified tokens from the Ark
     * - Starts an auction for each swept token
     * @custom:effects
     * - Updates obtainedTokens mapping
     * - Creates new auctions
     * @custom:security-considerations
     * - Validate input parameters
     */
    function sweepAndStartAuction(
        address ark,
        address[] calldata tokens
    ) external;

    /**
     * @dev Starts a Dutch auction for the harvested rewards of a specific Ark and reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token to be auctioned
     * @custom:internal-logic
     * - Creates a new auction for the specified reward token
     * - Resets obtainedTokens and unsoldTokens for the given Ark and reward token
     * @custom:effects
     * - Creates a new auction
     * - Updates obtainedTokens and unsoldTokens mappings
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Check for existing auctions before starting a new one
     */
    function startAuction(address ark, address rewardToken) external;

    /**
     * @dev Allows users to buy tokens from an active auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token being auctioned
     * @param amount The amount of tokens to purchase
     * @return paymentAmount The amount of payment tokens required to purchase the specified amount of reward tokens
     * @custom:internal-logic
     * - Retrieves the auction data for the specified Ark and reward token
     * - Calls the buyTokens function of the DutchAuctionLibrary
     * - Updates the paymentTokensToBoard mapping
     * - Settles the auction if all tokens are sold
     * @custom:effects
     * - Transfers tokens between the buyer and the contract
     * - Updates the auction state
     * - May settle the auction if all tokens are sold
     * @custom:security-considerations
     * - Ensure proper token transfers and balance updates
     * - Handle potential reentrancy risks
     */
    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external returns (uint256 paymentAmount);

    /**
     * @dev Finalizes an auction after its end time has been reached
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token that was auctioned
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the finalizeAuction function of the DutchAuctionLibrary
     * - Settles the auction
     * - if an ark doesn't require keeper data, the raised funds will be boarded autoamtically
     * @custom:effects
     * - Updates the auction state
     * - May transfer unsold tokens
     * - May initiate boarding of payment tokens
     * @custom:security-considerations
     * - Ensure the auction has ended before finalizing
     * - Handle potential edge cases with unsold tokens
     */
    function finalizeAuction(address ark, address rewardToken) external;

    /**
     * @dev Gets the current price of tokens in an ongoing auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @return The current price of the auction
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the getCurrentPrice function of the DutchAuctionLibrary
     * @custom:effects
     * - No state changes (view function)
     * @custom:security-considerations
     * - Ensure the auction is ongoing when calling this function
     */
    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256);

    /**
     * @dev Boards the auctioned token to an Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token to board the rewards to
     * @param data Additional data required by the Ark to board rewards
     * @custom:internal-logic
     * - Checks if the Ark requires keeper data
     * - Approves and boards the payment tokens to the Ark
     * @custom:effects
     * - Transfers payment tokens to the Ark
     * - Resets the paymentTokensToBoard mapping
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Validate the Ark address and data
     * - Handle potential failures in the boarding process
     */
    function board(
        address ark,
        address rewardToken,
        bytes calldata data
    ) external;

    /**
     * @notice Sets whether a token can be swept from an Ark
     * @param ark The address of the Ark
     * @param token The token address
     * @param isSweepable Whether the token should be sweepable
     * @custom:internal-logic
     * - Sets the sweepableTokens mapping for the specified Ark and token
     * @custom:effects
     * - Updates the sweepableTokens mapping
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     * - Validate the Ark address and token address
     */
    function setSweepableToken(
        address ark,
        address token,
        bool isSweepable
    ) external;

    /**
     * @dev Sets the auction parameters for a specific Ark and reward token
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     * @param parameters The auction parameters to set
     * @custom:internal-logic
     * - Sets the auction parameters for the specified Ark and reward token
     * @custom:effects
     * - Updates the auction parameters
     * @custom:security-considerations
     * - Ensure only authorized addresses can call this function
     */
    function setArkAuctionParameters(
        address ark,
        address rewardToken,
        BaseAuctionParameters calldata parameters
    ) external;
}

// src/contracts/Raft.sol

/**
 * @title Raft
 * @notice Manages auctions for harvested rewards from Arks and handles the auction mechanism
 * @dev Implements IRaft interface and inherits from ArkAccessManaged and AuctionManagerBase
 * @custom:see IRaft
 */
contract Raft is IRaft, ArkAccessManaged, AuctionManagerBase {
    using SafeERC20 for IERC20;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of harvested rewards for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => uint256 harvestedAmount))
        public obtainedTokens;

    /// @notice Mapping of ongoing auctions for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => DutchAuctionLibrary.Auction))
        public auctions;

    /// @notice Mapping of unsold tokens for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => uint256 remainingTokens))
        public unsoldTokens;

    /// @notice Mapping of payment tokens boarded to each Ark and reward token
    mapping(address ark => mapping(address rewardToken => uint256 paymentTokensToBoard))
        public paymentTokensToBoard;

    /// @notice Mapping of tokens that are allowed to be swept for each Ark
    mapping(address ark => mapping(address token => bool isSweepable))
        public sweepableTokens;

    /// @notice Mapping of custom auction parameters for each Ark and reward token
    mapping(address ark => mapping(address rewardToken => BaseAuctionParameters))
        public arkAuctionParameters;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the Raft contract
     * @param _accessManager Address of the access manager contract
     */
    constructor(
        address _accessManager
    ) ArkAccessManaged(_accessManager) AuctionManagerBase() {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRaft
    function harvestAndStartAuction(
        address ark,
        bytes calldata rewardData
    ) external {
        (address[] memory harvestedTokens, ) = _harvest(ark, rewardData);
        for (uint256 i = 0; i < harvestedTokens.length; i++) {
            _startAuction(ark, harvestedTokens[i]);
        }
    }

    /// @inheritdoc IRaft
    function sweepAndStartAuction(
        address ark,
        address[] calldata tokens
    ) external {
        (address[] memory sweptTokens, ) = _sweep(ark, tokens);
        for (uint256 i = 0; i < sweptTokens.length; i++) {
            _startAuction(ark, sweptTokens[i]);
        }
    }

    /// @inheritdoc IRaft
    function startAuction(address ark, address rewardToken) public {
        _startAuction(ark, rewardToken);
    }

    /// @inheritdoc IRaft
    function harvest(address ark, bytes calldata rewardData) external {
        _harvest(ark, rewardData);
    }

    /// @inheritdoc IRaft
    function sweep(
        address ark,
        address[] calldata tokens
    )
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        (sweptTokens, sweptAmounts) = _sweep(ark, tokens);
    }

    /// @inheritdoc IRaft
    function buyTokens(
        address ark,
        address rewardToken,
        uint256 amount
    ) external returns (uint256 paymentAmount) {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        paymentAmount = auction.buyTokens(amount);

        paymentTokensToBoard[ark][rewardToken] += paymentAmount;

        if (auction.state.remainingTokens == 0) {
            _settleAuction(ark, rewardToken, auction);
        }
    }

    /// @inheritdoc IRaft
    function finalizeAuction(address ark, address rewardToken) external {
        DutchAuctionLibrary.Auction storage auction = auctions[ark][
            rewardToken
        ];
        auction.finalizeAuction();
        _settleAuction(ark, rewardToken, auction);
    }

    /// @inheritdoc IRaft
    function board(
        address ark,
        address rewardToken,
        bytes calldata data
    ) external {
        if (!IArk(ark).requiresKeeperData()) {
            revert RaftArkDoesntRequireKeeperData(ark);
        }
        _board(rewardToken, ark, data);
    }

    /// @inheritdoc IRaft
    function setSweepableToken(
        address ark,
        address token,
        bool isSweepable
    ) external onlyCurator(IArk(ark).commander()) {
        sweepableTokens[ark][token] = isSweepable;
        emit SweepableTokenSet(ark, token, isSweepable);
    }

    /// @inheritdoc IRaft
    function setArkAuctionParameters(
        address ark,
        address rewardToken,
        BaseAuctionParameters calldata parameters
    ) external onlyCurator(IArk(ark).commander()) {
        if (parameters.duration == 0) {
            revert RaftInvalidAuctionParameters(ark, rewardToken);
        }
        arkAuctionParameters[ark][rewardToken] = parameters;
        emit ArkAuctionParametersSet(ark, rewardToken, parameters);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRaft
    function getCurrentPrice(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return _getCurrentPrice(auctions[ark][rewardToken]);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Harvests rewards from the specified Ark
     * @param ark The address of the Ark to harvest from
     * @param rewardData Additional data required for harvesting
     * @return harvestedTokens Array of harvested token addresses
     * @return harvestedAmounts Array of harvested token amounts
     */
    function _harvest(
        address ark,
        bytes calldata rewardData
    )
        internal
        onlySuperKeeper
        returns (
            address[] memory harvestedTokens,
            uint256[] memory harvestedAmounts
        )
    {
        (harvestedTokens, harvestedAmounts) = IArk(ark).harvest(rewardData);
        for (uint256 i = 0; i < harvestedTokens.length; i++) {
            obtainedTokens[ark][harvestedTokens[i]] += harvestedAmounts[i];
        }

        emit ArkHarvested(ark, harvestedTokens, harvestedAmounts);
    }

    /**
     * @notice Sweeps tokens from the specified Ark
     * @dev Sweeps tokens from the specified Ark and updates the obtainedTokens mapping
     * @param ark The address of the Ark contract to sweep tokens from
     * @param tokens The addresses of the tokens to sweep
     * @return sweptTokens The addresses of the tokens that were swept
     * @return sweptAmounts The amounts of the tokens that were swept
     * @custom:internal-logic
     * - Calls the sweep function on the specified Ark contract
     * - Iterates through the swept tokens and updates the obtainedTokens mapping
     * @custom:effects
     * - Updates the obtainedTokens mapping for each swept token
     * - Transfers swept tokens from the Ark to this contract
     * @custom:security-considerations
     * - Validate the Ark address and token addresses
     * - Handle potential failures in the Ark's sweep function
     * - Be aware of potential gas limitations when sweeping a large number of tokens
     */
    function _sweep(
        address ark,
        address[] calldata tokens
    )
        internal
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        // Add validation for sweepable tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!sweepableTokens[ark][tokens[i]]) {
                revert RaftTokenNotSweepable(ark, tokens[i]);
            }
        }
        (sweptTokens, sweptAmounts) = IArk(ark).sweep(tokens);
        for (uint256 i = 0; i < sweptTokens.length; i++) {
            obtainedTokens[ark][sweptTokens[i]] += sweptAmounts[i];
        }
    }

    /**
     * @notice Starts a new auction for a specific Ark and reward token
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token to be auctioned
     * @custom:internal-logic
     * - Checks if there's an existing, unfinalized auction for the given Ark and reward token
     * - Calculates the total tokens to be auctioned (obtained + unsold)
     * - Creates a new auction using the _createAuction function
     * - Resets the obtainedTokens and unsoldTokens for the given Ark and reward token
     * @custom:effects
     * - Creates a new auction in the auctions mapping
     * - Resets obtainedTokens and unsoldTokens for the given Ark and reward token
     * - Emits an ArkRewardTokenAuctionStarted event
     * @custom:security-considerations
     * - Ensure that there's no existing unfinalized auction before starting a new one
     * - Validate that the total tokens to be auctioned is greater than zero
     */
    function _startAuction(address ark, address rewardToken) internal {
        // Check if parameters are set by checking duration
        if (arkAuctionParameters[ark][rewardToken].duration == 0) {
            revert RaftAuctionParametersNotSet(ark, rewardToken);
        }

        DutchAuctionLibrary.Auction storage existingAuction = auctions[ark][
            rewardToken
        ];
        if (
            existingAuction.config.auctionToken != IERC20(address(0)) &&
            !existingAuction.state.isFinalized
        ) {
            revert RaftAuctionAlreadyRunning(ark, rewardToken);
        }

        uint256 totalTokens = obtainedTokens[ark][rewardToken] +
            unsoldTokens[ark][rewardToken];

        DutchAuctionLibrary.Auction
            memory newAuction = _createAuctionWithParams(
                IERC20(rewardToken),
                IERC20(IArk(ark).asset()),
                totalTokens,
                address(this),
                arkAuctionParameters[ark][rewardToken]
            );
        auctions[ark][rewardToken] = newAuction;

        obtainedTokens[ark][rewardToken] = 0;
        unsoldTokens[ark][rewardToken] = 0;

        emit ArkRewardTokenAuctionStarted(
            newAuction.config.id,
            ark,
            rewardToken,
            totalTokens
        );
    }

    /**
     * @notice Settles an auction by handling unsold tokens and initiating boarding process
     * @param ark The address of the Ark
     * @param rewardToken The address of the reward token
     * @param auction The auction to be settled
     * @custom:internal-logic
     * - Adds any remaining tokens from the auction to the unsoldTokens mapping
     * - If the Ark doesn't require keeper data, initiates the boarding process
     * @custom:effects
     * - Updates the unsoldTokens mapping
     * - May initiate the boarding process for the Ark
     * @custom:security-considerations
     * - Ensure that the auction is finalized before settling
     * - Handle potential failures in the boarding process
     */
    function _settleAuction(
        address ark,
        address rewardToken,
        DutchAuctionLibrary.Auction memory auction
    ) internal {
        unsoldTokens[ark][rewardToken] += auction.state.remainingTokens;
        if (!IArk(ark).requiresKeeperData()) {
            _board(rewardToken, ark, bytes(""));
        }
    }

    /**
     * @notice Boards the payment tokens to the Ark
     * @param rewardToken The address of the reward token
     * @param ark The address of the Ark
     * @param data The data to be passed to the Ark
     * @custom:internal-logic
     * - Retrieves the auction data for the given Ark and reward token
     * - Checks if there's a balance of payment tokens to board
     * - Approves the Ark to spend the payment tokens
     * - Calls the board function on the Ark contract
     * @custom:effects
     * - Approves the Ark to spend payment tokens
     * - Transfers payment tokens to the Ark
     * - Resets the paymentTokensToBoard balance
     * - Emits a RewardBoarded event
     * @custom:security-considerations
     * - Ensure that the Ark contract is trusted and properly implemented
     * - Handle potential failures in the token approval or boarding process
     * - Validate that the balance to board is greater than zero
     */
    function _board(
        address rewardToken,
        address ark,
        bytes memory data
    ) internal {
        IERC20 paymentToken = auctions[ark][rewardToken].config.paymentToken;

        uint256 balance = paymentTokensToBoard[ark][rewardToken];
        if (balance > 0) {
            paymentToken.forceApprove(ark, balance);
            IArk(ark).board(balance, data);

            emit RewardBoarded(
                ark,
                rewardToken,
                address(paymentToken),
                balance
            );
            paymentTokensToBoard[ark][rewardToken] = 0;
        }
    }
}
