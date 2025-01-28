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

/// @dev This interface is used for factorizing IUniversalRewardsDistributorStaticTyping and
/// IUniversalRewardsDistributor.
/// @dev Consider using the IUniversalRewardsDistributor interface instead of this one.
interface IUniversalRewardsDistributor {
    function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external;

    function claim(
        address account,
        address reward,
        uint256 claimable,
        bytes32[] memory proof
    ) external returns (uint256 amount);

    event Claimed(
        address indexed account,
        address indexed reward,
        uint256 amount
    );
}
