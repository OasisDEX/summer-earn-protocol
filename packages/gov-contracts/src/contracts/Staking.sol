// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/// @dev this is a minimal vesting factory interface
interface IMinimalVestingFactory {
    /// @dev each user can have a single vesting wallet - the balance of the vesting wallet can only go down
    function vestingWallets(address _user) external view returns (address);
    /// @dev the owner of the vesting wallet
    function vestingWalletOwners(
        address _wallet
    ) external view returns (address);
}

/// @dev this is a minimal vesting wallet interface
interface IMinimalVestingWallet {
    /// @dev the balance of the vesting wallet can only go down - if it goes up - tokens were sent to the wallet (unintended bhavior)
    function balanceOf(address _user) external view returns (uint256);
    /// @dev the current owner of the vesting wallet ( might be different that owner in the factory contract)
    function owner() external view returns (address);
    /// @dev the ownership of the vesting wallet can be trnsfered - this is used to transfer the ownership of the vesting wallet to the user
    function transferOwnership(address newOwner) external;
    /// @dev the amount of tokens released from the vesting wallet
    function released(address _token) external view returns (uint256);
}
// @dev this is a mvp for staking, it will be replaced with a more complex staking contract
// @dev this contract will be used to stake and unstake SUMMER_TOKEN for STAKED_SUMMER_TOKEN
contract Staking is ProtocolAccessManaged {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;
    EnumerableSet.AddressSet private _vestingFactories;
    mapping(address user => EnumerableMap.AddressToUintMap stakedVestingFactories)
        private _userStakedVestingFactories;
    mapping(address user => EnumerableMap.AddressToUintMap stakedVestingFactoriesReleased)
        private _userStakedVestingFactoriesReleased;

    constructor(
        address _protocolAccessManager,
        address _summerToken,
        address _xSumr,
        address[] memory _initialVestingFactories
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

        for (uint256 i = 0; i < _initialVestingFactories.length; i++) {
            if (_initialVestingFactories[i] == address(0)) {
                revert Staking_InvalidAddress(
                    "Vesting factory address cannot be zero"
                );
            }
            _vestingFactories.add(_initialVestingFactories[i]);
        }
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

    function vestingFactories() external view returns (address[] memory) {
        return _vestingFactories.values();
    }
    /**
     * @dev Returns the vesting factory at the specified index
     */
    function getVestingFactory(uint256 index) external view returns (address) {
        if (index >= _vestingFactories.length()) {
            revert Staking_InvalidIndex();
        }
        return _vestingFactories.at(index);
    }

    function userStakedVestingFactories(
        address _user
    ) external view returns (address[] memory) {
        return _userStakedVestingFactories[_user].keys();
    }

    function getUserStakedVestingFactory(
        address _user,
        uint256 _index
    ) external view returns (address) {
        (address factory, ) = _userStakedVestingFactories[_user].at(_index);
        return factory;
    }

    /**
     * @dev Adds a new vesting factory to the array
     * @param _vestingFactory The vesting factory address to add
     */
    function addVestingFactory(address _vestingFactory) external onlyGovernor {
        if (_vestingFactory == address(0)) {
            revert Staking_InvalidAddress(
                "Vesting factory address cannot be zero"
            );
        }

        if (!_vestingFactories.add(_vestingFactory)) {
            revert Staking_DuplicateFactory();
        }
        emit VestingFactoryAdded(_vestingFactory);
    }

    /**
     * @dev Removes a vesting factory from the array
     * @param _vestingFactory The vesting factory address to remove
     */
    function removeVestingFactory(
        address _vestingFactory
    ) external onlyGovernor {
        if (_vestingFactory == address(0)) {
            revert Staking_InvalidAddress(
                "Vesting factory address cannot be zero"
            );
        }

        if (!_vestingFactories.remove(_vestingFactory)) {
            revert Staking_FactoryNotFound();
        }

        emit VestingFactoryRemoved(_vestingFactory);
    }

    function stakeWithVesting() public {
        uint256 totalBalance = 0;

        for (uint256 i = 0; i < _vestingFactories.length(); i++) {
            IMinimalVestingFactory vestingFactory = IMinimalVestingFactory(
                _vestingFactories.at(i)
            );
            /// @dev only the original owner of the vesting wallet can stake from it
            /// @dev if the ownership was transferred to the user - the user can't stake from it
            address vestingWallet = vestingFactory.vestingWallets(msg.sender);
            // if the vesting wallet is not empty and the user has not staked from this vesting factory yet
            if (
                vestingWallet != address(0) &&
                !_userStakedVestingFactories[msg.sender].contains(
                    address(vestingFactory)
                )
            ) {
                uint256 balance = _stakeVestingWallet(vestingWallet);
                uint256 released = IMinimalVestingWallet(vestingWallet)
                    .released(address(SUMMER_TOKEN));
                totalBalance += balance;
                _userStakedVestingFactories[msg.sender].set(
                    address(vestingFactory),
                    balance
                );
                _userStakedVestingFactoriesReleased[msg.sender].set(
                    address(vestingFactory),
                    released
                );
            }
        }

        if (totalBalance > 0) {
            _mint(msg.sender, totalBalance);
        } else {
            revert Staking_VestingWalletsEmpty();
        }
    }

    function unstakeVesting() public {
        uint256 totalBalance = 0;

        while (_userStakedVestingFactories[msg.sender].length() > 0) {
            (
                address factory,
                uint256 stakedBalance
            ) = _userStakedVestingFactories[msg.sender].at(
                    _userStakedVestingFactories[msg.sender].length() - 1
                );

            IMinimalVestingFactory vestingFactory = IMinimalVestingFactory(
                factory
            );
            address vestingWallet = vestingFactory.vestingWallets(msg.sender);

            if (vestingWallet != address(0)) {
                _unstakeVestingWallet(
                    msg.sender,
                    vestingWallet,
                    vestingFactory
                );
                totalBalance += stakedBalance;
            }
            _userStakedVestingFactories[msg.sender].remove(
                address(vestingFactory)
            );
        }
        if (totalBalance > 0) {
            STAKED_SUMMER_TOKEN.safeTransferFrom(
                msg.sender,
                address(this),
                totalBalance
            );
            _burn(totalBalance);
        } else {
            revert Staking_NoVestingWalletsStaked();
        }
    }

    /**
     * @dev Internal method to stake tokens from a single vesting wallet
     * @dev all or nothing - if user owns multiple vesting wallets - they can't stake only from some of them
     * @param _vestingWallet The vesting wallet address
     * @return The amount staked from this vesting wallet
     */
    function _stakeVestingWallet(
        address _vestingWallet
    ) internal view returns (uint256) {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking__InvalidOwner("Vesting wallet not owned by staking");
        }

        uint256 balance = SUMMER_TOKEN.balanceOf(_vestingWallet);
        return balance;
    }

    /**
     * @dev Internal method to unstake tokens from a single vesting wallet
     * @dev all or nothing - if user owns multiple vesting wallets - they can't unstake only from some of them
     * @param _user The user address
     * @param _vestingWallet The vesting wallet address
     */
    function _unstakeVestingWallet(
        address _user,
        address _vestingWallet,
        IMinimalVestingFactory _vestingFactory
    ) internal {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking__InvalidOwner("Vesting wallet not owned by staking");
        }

        uint256 balance = SUMMER_TOKEN.balanceOf(_vestingWallet);
        address originalOwner = _vestingFactory.vestingWalletOwners(
            _vestingWallet
        );

        uint256 releasedAtStake = _userStakedVestingFactoriesReleased[
            msg.sender
        ].get(address(_vestingFactory));
        uint256 releasedAtUnstake = IMinimalVestingWallet(_vestingWallet)
            .released(address(SUMMER_TOKEN));
        uint256 releasedWhileStaked = releasedAtUnstake - releasedAtStake;
        if (releasedWhileStaked > 0) {
            SUMMER_TOKEN.safeTransfer(originalOwner, releasedWhileStaked);
        }
        if (balance > 0 && originalOwner == _user) {
            IMinimalVestingWallet(_vestingWallet).transferOwnership(_user);
        }
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
