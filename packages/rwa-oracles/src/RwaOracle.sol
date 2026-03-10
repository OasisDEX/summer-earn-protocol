// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {IRwaOracle} from "./interfaces/IRwaOracle.sol";

/**
 * @title RwaOracle
 * @author Summer
 * @notice Chainlink-compatible price oracle for RWA assets with multi-sig price updates.
 * @dev Implements AggregatorV3Interface for drop-in use with Chainlink consumers.
 *      Price updates require a threshold of valid EIP-712 signatures from authorized signers.
 *      Signatures must be sorted ascending by signer address.
 */
contract RwaOracle is Ownable, AggregatorV3Interface, IRwaOracle, EIP712 {
    using ECDSA for bytes32;

    /// @dev EIP-712 typehash for PriceUpdate struct
    bytes32 public constant PRICE_UPDATE_TYPEHASH =
        keccak256(
            "PriceUpdate(int256 price,uint256 timestamp,uint256 nonce,address oracle,uint256 chainId)"
        );

    /// @notice Human-readable description of this price feed
    string public description;
    /// @notice Number of decimals in the price (Chainlink standard)
    uint8 public constant decimals = 8;
    /// @notice Version for EIP-712 domain
    uint256 public constant version = 1;

    /// @notice Minimum number of valid signatures required to update price
    uint256 public threshold;
    /// @notice List of authorized signer addresses
    address[] public signersList;
    /// @notice Whether an address is an authorized signer
    mapping(address => bool) public isSigner;

    /// @notice Latest round identifier
    uint80 public latestRoundId;
    /// @notice Latest price (8 decimals, e.g. 8.74e8 for $8.74)
    int256 public latestPrice;
    /// @notice Timestamp of the latest price update
    uint256 public latestTimestamp;
    /// @notice Nonce used in EIP-712 hashing to prevent replay
    uint256 public nonce;

    /// @notice Round data stored for historical queries
    struct RoundData {
        int256 price;
        uint256 timestamp;
        uint80 roundId;
    }

    /// @notice Round ID => round data
    mapping(uint80 => RoundData) public rounds;

    /**
     * @param _description Human-readable description of the price feed.
     * @param _signers Initial list of authorized signer addresses.
     * @param _threshold Minimum signatures required for price update (must be 1 <= threshold <= signers.length).
     * @param _owner Owner address (manages signers and threshold).
     */
    constructor(
        string memory _description,
        address[] memory _signers,
        uint256 _threshold,
        address _owner
    ) Ownable(_owner) EIP712("RwaOracle", "1") {
        description = _description;
        threshold = _threshold;

        for (uint256 i = 0; i < _signers.length; i++) {
            if (_signers[i] == address(0)) revert InvalidConfiguration();
            if (isSigner[_signers[i]]) revert InvalidConfiguration(); // Duplicate check
            _addSigner(_signers[i]);
        }

        if (threshold == 0 || threshold > _signers.length) {
            revert InvalidConfiguration();
        }
    }

    // --- AggregatorV3Interface ---

    /**
     * @notice Get data for a specific round (Chainlink compatibility).
     * @param _roundId Round identifier.
     * @return roundId The round ID.
     * @return answer Price for the round.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was updated.
     * @return answeredInRound Round in which the answer was computed.
     */
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (_roundId == 0 || _roundId > latestRoundId) revert NoDataPresent();
        RoundData memory round = rounds[_roundId];
        return (
            _roundId,
            round.price,
            round.timestamp,
            round.timestamp,
            _roundId
        );
    }

    /**
     * @notice Get the latest round data (Chainlink compatibility).
     * @return roundId Latest round ID.
     * @return answer Latest price.
     * @return startedAt Timestamp of the round.
     * @return updatedAt Timestamp of the round.
     * @return answeredInRound Same as roundId.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (latestRoundId == 0) revert NoDataPresent();
        return (
            latestRoundId,
            latestPrice,
            latestTimestamp,
            latestTimestamp,
            latestRoundId
        );
    }

    // --- Update Logic ---

    /**
     * @notice Update the oracle price with multi-sig authorization.
     * @param price New price (8 decimals).
     * @param timestamp Unix timestamp of the price (must be newer than latest and not in future).
     * @param signatures Array of EIP-712 signatures from authorized signers (sorted ascending by address).
     * @dev Requires at least `threshold` valid signatures. Reverts on StalePrice, FuturePrice, NotEnoughSignatures, Unauthorized, InvalidSignature.
     */
    function updatePrice(
        int256 price,
        uint256 timestamp,
        bytes[] calldata signatures
    ) external {
        if (timestamp <= latestTimestamp) revert StalePrice();
        if (timestamp > block.timestamp + 1 hours) revert FuturePrice(); // Basic sanity check

        // EIP-712: structured data so wallets show price, timestamp, nonce, etc.
        bytes32 structHash = keccak256(
            abi.encode(
                PRICE_UPDATE_TYPEHASH,
                price,
                timestamp,
                nonce,
                address(this),
                block.chainid
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        _verifySignatures(digest, signatures);

        // Update State
        latestRoundId++;
        latestPrice = price;
        latestTimestamp = timestamp;
        nonce++;

        rounds[latestRoundId] = RoundData({
            price: price,
            timestamp: timestamp,
            roundId: latestRoundId
        });

        emit PriceUpdated(price, timestamp, latestRoundId);
    }

    /**
     * @dev Verifies that the hash has at least `threshold` valid signatures from unique, sorted signers.
     */
    function _verifySignatures(
        bytes32 hash,
        bytes[] calldata signatures
    ) internal view {
        if (signatures.length < threshold) revert NotEnoughSignatures();

        address lastSigner = address(0);

        // Signatures must be sorted by signer address ascending to prevent duplicates easily
        // But for simplicity, we can just track duplicates in memory if needed.
        // However, sorted requirement is gas efficient.
        // Let's enforce sorted unique addresses.

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = hash.recover(signatures[i]);
            if (!isSigner[recovered]) revert Unauthorized();
            if (recovered <= lastSigner) revert InvalidSignature(); // Enforce sorted and unique
            lastSigner = recovered;
        }
    }

    // --- Admin ---

    /**
     * @notice Add an authorized signer.
     * @param signer Address to add. Must not be zero or already a signer.
     */
    function addSigner(address signer) external onlyOwner {
        if (signer == address(0)) revert InvalidConfiguration();
        if (isSigner[signer]) return;
        _addSigner(signer);
        emit SignerAdded(signer);
    }

    /**
     * @notice Remove a signer.
     * @param signer Address to remove.
     * @dev Reverts if removal would leave fewer signers than threshold. Lower threshold first if needed.
     */
    function removeSigner(address signer) external onlyOwner {
        if (!isSigner[signer]) return;

        // Remove from list
        for (uint256 i = 0; i < signersList.length; i++) {
            if (signersList[i] == signer) {
                signersList[i] = signersList[signersList.length - 1];
                signersList.pop();
                break;
            }
        }

        isSigner[signer] = false;

        if (signersList.length < threshold) {
            revert InvalidConfiguration(); // Must lower threshold first
        }
        emit SignerRemoved(signer);
    }

    /**
     * @notice Set the minimum number of signatures required for price updates.
     * @param _threshold New threshold. Must be > 0 and <= current signer count.
     */
    function setThreshold(uint256 _threshold) external onlyOwner {
        if (_threshold == 0 || _threshold > signersList.length)
            revert InvalidConfiguration();
        threshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }

    /// @dev Internal helper to add a signer to the list and mapping.
    function _addSigner(address signer) internal {
        isSigner[signer] = true;
        signersList.push(signer);
    }
}
