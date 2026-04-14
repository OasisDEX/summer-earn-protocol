import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "@summerfi/access-contracts/interfaces/IProtocolAccessManagerV2.sol";

contract MockAccessManager {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    mapping(bytes32 => mapping(address => bool)) public roles;

    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool) {
        return roles[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        roles[role][account] = true;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IProtocolAccessManagerV2).interfaceId ||
            interfaceId == type(IProtocolAccessManager).interfaceId;
    }

    mapping(address => bool) public whitelisted;

    function setWhitelisted(address account, bool isWhitelisted_) external {
        whitelisted[account] = isWhitelisted_;
    }

    function isWhitelisted(address account) external view returns (bool) {
        // If address(0) is whitelisted, the gateway is globally open
        return whitelisted[address(0)] || whitelisted[account];
    }
}
