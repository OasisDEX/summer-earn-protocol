// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

/**
 * @title DescriptionHash
 * @dev Utility contract for computing description hashes for governance proposals
 * in a way that's identical to how they're computed in the Governor contract.
 */
contract DescriptionHash is Test {
    /**
     * @dev Computes the keccak256 hash of a proposal description
     * @param description The proposal description string
     * @return The bytes32 hash of the description
     */
    function hash(string memory description) public pure returns (bytes32) {
        return keccak256(bytes(description));
    }

    /**
     * @dev Test function to log a description hash
     * @param description The proposal description to hash
     */
    function logDescriptionHash(string memory description) public view {
        bytes32 descHash = this.hash(description);
        console.log("Description: ", description);
        console.logBytes32(descHash);
    }

    /**
     * @dev Test function to compare if two descriptions produce the same hash
     * @param description1 First description
     * @param description2 Second description
     * @return true if hashes match, false otherwise
     */
    function compareHashes(
        string memory description1,
        string memory description2
    ) public pure returns (bool) {
        return hash(description1) == hash(description2);
    }
}
