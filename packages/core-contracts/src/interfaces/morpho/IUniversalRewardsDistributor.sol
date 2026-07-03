// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @notice The pending root struct for a merkle tree distribution during the timelock.
struct PendingRoot {
    /// @dev The submitted pending root.
    bytes32 root;
    /// @dev The optional ipfs hash containing metadata about the root (e.g. the merkle tree itself).
    bytes32 ipfsHash;
    /// @dev The timestamp at which the pending root can be accepted.
    uint256 validAt;
}

/// @title IUniversalRewardsDistributor
/// @notice Interface for Morpho's Universal Rewards Distributor (Merkle-based rewards)
/// @dev This interface is used for factorizing IUniversalRewardsDistributorStaticTyping and
/// IUniversalRewardsDistributor.
/// @dev Consider using the IUniversalRewardsDistributor interface instead of this one.
interface IUniversalRewardsDistributor {
    /// @notice Submits a new Merkle root and optional IPFS hash (subject to timelock)
    /// @param newRoot The new Merkle root
    /// @param newIpfsHash The optional IPFS hash with metadata about the root
    function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external;

    /// @notice Claims rewards for an account using a Merkle proof
    /// @param account The account to claim for
    /// @param reward The reward token to claim
    /// @param claimable The cumulative claimable amount encoded in the Merkle tree
    /// @param proof The Merkle proof for the claim
    /// @return amount The amount of rewards transferred
    function claim(
        address account,
        address reward,
        uint256 claimable,
        bytes32[] memory proof
    ) external returns (uint256 amount);

    /// @notice Emitted when rewards are claimed
    /// @param account The account that received the rewards
    /// @param reward The reward token claimed
    /// @param amount The amount claimed
    event Claimed(
        address indexed account,
        address indexed reward,
        uint256 amount
    );
}
