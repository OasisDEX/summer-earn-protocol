// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";

contract StakedSummerToken is
    IStakedSummerToken,
    ERC20Burnable,
    ERC20Pausable,
    ProtocolAccessManaged,
    AccessControl,
    ERC20Permit,
    ERC20Votes
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        address _protocolAccessManager
    )
        ERC20("StakedSummerToken", "xSUMR")
        ERC20Permit("StakedSummerToken")
        ProtocolAccessManaged(_protocolAccessManager)
    {}

    function addStakingModule(address _stakingModule) public onlyGovernor {
        if (_stakingModule == address(0)) {
            revert xSumr_InvalidStakingModule(
                "Staking module address cannot be zero"
            );
        }
        _grantRole(MINTER_ROLE, _stakingModule);
        _grantRole(BURNER_ROLE, _stakingModule);

        emit StakingModuleAdded(_stakingModule);
    }

    function removeStakingModule(address _stakingModule) public onlyGovernor {
        _revokeRole(MINTER_ROLE, _stakingModule);
        _revokeRole(BURNER_ROLE, _stakingModule);
        emit StakingModuleRemoved(_stakingModule);
    }

    function pause() public onlyGuardianOrGovernor {
        _pause();
    }

    function unpause() public onlyGuardianOrGovernor {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(
        uint256 amount
    ) public override(ERC20Burnable, IStakedSummerToken) {
        super.burn(amount);
    }

    function burnFrom(
        address from,
        uint256 amount
    ) public override(ERC20Burnable, IStakedSummerToken) {
        if (msg.sender != from && !hasRole(BURNER_ROLE, msg.sender)) {
            revert xSumr__NotAuthorized();
        }
        super.burnFrom(from, amount);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        if (!_canTransfer(from, to)) {
            revert xSumr_TransferNotAllowed();
        }
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function grantMinterRole(address _minter) public onlyGovernor {
        _grantRole(MINTER_ROLE, _minter);
    }

    function revokeMinterRole(address _minter) public onlyGovernor {
        _revokeRole(MINTER_ROLE, _minter);
    }

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

    function _canTransfer(
        address from,
        address to
    ) internal view returns (bool) {
        return from == address(0) || to == address(0);
    }
}
