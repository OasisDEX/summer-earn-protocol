// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {xSumr} from "./xSumr.sol";

// @dev this is a mvp for staking, it will be replaced with a more complex staking contract
// @dev this contract will be used to stake and unstake SUMMER_TOKEN for xSUMR
contract Staking is ProtocolAccessManaged {
    using SafeERC20 for IERC20;

    IERC20 public immutable SUMMER_TOKEN;
    IERC20 public immutable xSUMR;

    constructor(
        address _protocolAccessManager,
        address _summerToken,
        address _xSumr
    ) ProtocolAccessManaged(_protocolAccessManager) {
        if (_summerToken == address(0)) {
            revert Staking_InvalidAddress(
                "Summer token address cannot be zero"
            );
        }
        if (_xSumr == address(0)) {
            revert Staking_InvalidAddress("xSumr address cannot be zero");
        }
        SUMMER_TOKEN = IERC20(_summerToken);
        xSUMR = IERC20(_xSumr);
    }

    function stake(uint256 _amount) public {
        SUMMER_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function unstake(uint256 _amount) public {
        xSUMR.safeTransferFrom(msg.sender, address(this), _amount);
        SUMMER_TOKEN.safeTransfer(msg.sender, _amount);
        _burn(msg.sender, _amount);
    }

    function _burn(address _user, uint256 _amount) internal {
        xSumr(address(xSUMR)).burn(_amount);
    }

    function _mint(address _user, uint256 _amount) internal {
        xSumr(address(xSUMR)).mint(_user, _amount);
    }

    error Staking_InvalidAddress(string message);
}
