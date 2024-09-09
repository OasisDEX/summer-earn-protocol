// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/governance/IGovernor.sol";

interface ISummerGovernor is IGovernor {
    event WhitelistAccountExpirationSet(
        address indexed account,
        uint256 expiration
    );
    event WhitelistGuardianSet(address indexed newGuardian);

    function pause() external;
    function unpause() external;
    function isWhitelisted(address account) external view returns (bool);
    function setWhitelistAccountExpiration(
        address account,
        uint256 expiration
    ) external;
    function setWhitelistGuardian(address _whitelistGuardian) external;
}
