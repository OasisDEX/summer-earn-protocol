// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRwaOracleErrors {
    error InvalidSignature();
    error NotEnoughSignatures();
    error StalePrice();
    error FuturePrice();
    error Unauthorized();
    error InvalidConfiguration();
    error DuplicateSigner();
}
