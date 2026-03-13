// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Minimal Permit2 interface for signature transfers
interface ISignatureTransfer {
    struct TokenPermissions {
        IERC20 token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface IPermit2 is ISignatureTransfer {
    // Other functions like allowance transfers not needed for simple deposits
}
