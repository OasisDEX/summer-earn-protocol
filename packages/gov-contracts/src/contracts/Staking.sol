// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @dev this is a minimal vesting factory interface
interface IMinimalVestingFactory {
    function vestingWallets(address _user) external view returns (address);
    function vestingWalletOwners(
        address _wallet
    ) external view returns (address);
}

/// @dev this is a minimal vesting wallet interface
interface IMinimalVestingWallet {
    function balanceOf(address _user) external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}
// @dev this is a mvp for staking, it will be replaced with a more complex staking contract
// @dev this contract will be used to stake and unstake SUMMER_TOKEN for STAKED_SUMMER_TOKEN
contract Staking is ProtocolAccessManaged {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;
    using EnumerableSet for EnumerableSet.AddressSet;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;
    EnumerableSet.AddressSet private _vestingFactories;

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
        _burn(msg.sender, _amount);
    }

    /**
     * @dev Returns the number of vesting factories
     */
    function getVestingFactoryCount() external view returns (uint256) {
        return _vestingFactories.length();
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
        bool hasVestingWallet = false;

        for (uint256 i = 0; i < _vestingFactories.length(); i++) {
            address vestingWallet = IMinimalVestingFactory(
                _vestingFactories.at(i)
            ).vestingWallets(msg.sender);
            if (vestingWallet != address(0)) {
                totalBalance += _stakeVestingWallet(msg.sender, vestingWallet);
                hasVestingWallet = true;
            }
        }

        if (!hasVestingWallet) {
            revert Staking_InvalidAddress("No vesting wallet found for user");
        }

        if (totalBalance > 0) {
            _mint(msg.sender, totalBalance);
        }
    }

    function unstakeVesting() public {
        uint256 totalBalance = 0;
        bool hasVestingWallet = false;

        for (uint256 i = 0; i < _vestingFactories.length(); i++) {
            address vestingWallet = IMinimalVestingFactory(
                _vestingFactories.at(i)
            ).vestingWallets(msg.sender);
            if (vestingWallet != address(0)) {
                totalBalance += _unstakeVestingWallet(
                    msg.sender,
                    vestingWallet,
                    IMinimalVestingFactory(_vestingFactories.at(i))
                );
                hasVestingWallet = true;
            }
        }

        if (!hasVestingWallet) {
            revert Staking_InvalidAddress("No vesting wallet found for user");
        }

        if (totalBalance > 0) {
            SUMMER_TOKEN.safeTransfer(msg.sender, totalBalance);
            _burn(msg.sender, totalBalance);
        }
    }

    /**
     * @dev Internal method to stake tokens from a single vesting wallet
     * @param _user The user address
     * @param _vestingWallet The vesting wallet address
     * @return The amount staked from this vesting wallet
     */
    function _stakeVestingWallet(
        address _user,
        address _vestingWallet
    ) internal returns (uint256) {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking__InvalidOwner("Vesting wallet not owned by staking");
        }

        uint256 balance = SUMMER_TOKEN.balanceOf(_vestingWallet);
        return balance;
    }

    /**
     * @dev Internal method to unstake tokens from a single vesting wallet
     * @param _user The user address
     * @param _vestingWallet The vesting wallet address
     * @return The amount unstaked from this vesting wallet
     */
    function _unstakeVestingWallet(
        address _user,
        address _vestingWallet,
        IMinimalVestingFactory _vestingFactory
    ) internal returns (uint256) {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking__InvalidOwner("Vesting wallet not owned by staking");
        }

        uint256 balance = SUMMER_TOKEN.balanceOf(_vestingWallet);
        address previousOwner = _vestingFactory.vestingWalletOwners(
            _vestingWallet
        );
        if (balance > 0 && previousOwner == _user) {
            IMinimalVestingWallet(_vestingWallet).transferOwnership(_user);
        }
        return balance;
    }

    function _burn(address _user, uint256 _amount) internal {
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

    event VestingFactoryAdded(address indexed vestingFactory);
    event VestingFactoryRemoved(address indexed vestingFactory);
}
