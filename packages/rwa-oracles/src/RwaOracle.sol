// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {IRwaOracle} from "./interfaces/IRwaOracle.sol";

contract RwaOracle is Ownable, AggregatorV3Interface, IRwaOracle, EIP712 {
    using ECDSA for bytes32;

    // EIP-712
    bytes32 public constant PRICE_UPDATE_TYPEHASH =
        keccak256(
            "PriceUpdate(int256 price,uint256 timestamp,uint256 nonce,address oracle,uint256 chainId)"
        );

    string public description;
    uint8 public constant decimals = 8;
    uint256 public constant version = 1;

    uint256 public threshold;
    address[] public signersList;
    mapping(address => bool) public isSigner;

    // Aggregator State
    uint80 public latestRoundId;
    int256 public latestPrice;
    uint256 public latestTimestamp;
    uint256 public nonce;

    struct RoundData {
        int256 price;
        uint256 timestamp;
        uint80 roundId;
    }

    mapping(uint80 => RoundData) public rounds;

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
        RoundData memory round = rounds[_roundId];
        return (
            _roundId,
            round.price,
            round.timestamp,
            round.timestamp,
            _roundId
        );
    }

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
        return (
            latestRoundId,
            latestPrice,
            latestTimestamp,
            latestTimestamp,
            latestRoundId
        );
    }

    // --- Update Logic ---

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

    function addSigner(address signer) external onlyOwner {
        if (signer == address(0)) revert InvalidConfiguration();
        if (isSigner[signer]) return;
        _addSigner(signer);
        emit SignerAdded(signer);
    }

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

    function setThreshold(uint256 _threshold) external onlyOwner {
        if (_threshold == 0 || _threshold > signersList.length)
            revert InvalidConfiguration();
        threshold = _threshold;
        emit ThresholdUpdated(_threshold);
    }

    function _addSigner(address signer) internal {
        isSigner[signer] = true;
        signersList.push(signer);
    }
}
