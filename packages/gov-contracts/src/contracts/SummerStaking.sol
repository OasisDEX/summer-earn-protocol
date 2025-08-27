// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";

// @dev this is a mvp for staking, it will be replaced with a more complex staking contract
// @dev this contract will be used to stake and unstake SUMMER_TOKEN for STAKED_SUMMER_TOKEN
contract SummerStaking is ProtocolAccessManaged {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;

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

        SUMMER_TOKEN = ISummerToken(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_xSumr);
    }

    function stake(uint256 _amount) public {
        SUMMER_TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function unstake(uint256 _amount) public {
        STAKED_SUMMER_TOKEN.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        SUMMER_TOKEN.safeTransfer(msg.sender, _amount);
        _burn(_amount);
    }

    function _burn(uint256 _amount) internal {
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).burn(_amount);
    }

    function _mint(address _user, uint256 _amount) internal {
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).mint(_user, _amount);
    }

    error Staking_InvalidAddress(string message);
    error Staking__InvalidOwner(string message);
    error Staking_InvalidIndex();
    error Staking_DuplicateFactory();
    error Staking_FactoryNotFound();
    error Staking_InvalidBalance();
    error Staking_VestingWalletsEmpty();
    error Staking_NoVestingWalletsStaked();

    event VestingFactoryAdded(address indexed vestingFactory);
    event VestingFactoryRemoved(address indexed vestingFactory);
}
