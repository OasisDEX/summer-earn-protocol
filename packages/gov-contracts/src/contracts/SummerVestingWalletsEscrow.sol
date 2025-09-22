// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {ISummerVestingWalletsEscrow} from "../interfaces/ISummerVestingWalletsEscrow.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IMinimalVestingFactory} from "../interfaces/IMinimalVestingFactory.sol";
import {IMinimalVestingWallet} from "../interfaces/IMinimalVestingWallet.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SummerVestingWalletsEscrow
 * @notice Escrow staking that mints xSUMR against SUMR balances held in vesting wallets
 * @dev Used to stake and unstake SUMMER_TOKEN for STAKED_SUMMER_TOKEN without moving funds from vesting wallets.
 *      While staked, vesting wallets must be owned by this contract. Released tokens during the staked period are
 *      forwarded back to the original vesting wallet owner during unstake.
 * @author Summer.fi Protocol
 */
contract SummerVestingWalletsEscrow is
    ISummerVestingWalletsEscrow,
    ProtocolAccessManaged,
    ReentrancyGuard
{
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // ============ IMMUTABLE STATE ============

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;

    // ============ STORAGE ============

    EnumerableSet.AddressSet private _vestingFactories;
    mapping(address user => EnumerableMap.AddressToUintMap stakedVestingFactories)
        private _userStakedVestingFactoriesBalance;
    mapping(address user => EnumerableMap.AddressToUintMap stakedVestingFactoriesReleased)
        private _userStakedVestingFactoriesReleased;

    // ============ CONSTRUCTOR ============

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
            revert Staking_InvalidAddress(
                "StakedSummerToken address cannot be zero"
            );
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

    /// @inheritdoc ISummerVestingWalletsEscrow
    function vestingFactories()
        external
        view
        override
        returns (address[] memory)
    {
        return _vestingFactories.values();
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function getVestingFactory(
        uint256 index
    ) external view override returns (address) {
        if (index >= _vestingFactories.length()) {
            revert Staking_InvalidIndex();
        }
        return _vestingFactories.at(index);
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function userStakedVestingFactories(
        address _user
    ) external view override returns (address[] memory) {
        return _userStakedVestingFactoriesBalance[_user].keys();
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function getUserStakedVestingFactory(
        address _user,
        uint256 _index
    ) external view override returns (address) {
        (address factory, ) = _userStakedVestingFactoriesBalance[_user].at(
            _index
        );
        return factory;
    }

    // ============ EXTERNAL FUNCTIONS - ADMIN ============

    /// @inheritdoc ISummerVestingWalletsEscrow
    function addVestingFactory(
        address _vestingFactory
    ) external override onlyGovernor {
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

    /// @inheritdoc ISummerVestingWalletsEscrow
    function removeVestingFactory(
        address _vestingFactory
    ) external override onlyGovernor {
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
    // ============ EXTERNAL FUNCTIONS - RESCUE ============

    /// @inheritdoc ISummerVestingWalletsEscrow
    function rescueWallet(
        address _wallet,
        address _newOwner
    ) external override onlyGovernor {
        if (_newOwner == address(0)) {
            revert Staking_InvalidAddress("New owner cannot be zero address");
        }
        IMinimalVestingWallet(_wallet).transferOwnership(_newOwner);
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function rescueToken(
        address _token,
        address _to
    ) external override onlyGovernor {
        if (_token == address(0)) {
            revert Staking_InvalidAddress("Invalid token address");
        }
        if (_to == address(0)) {
            revert Staking_InvalidAddress("Invalid to address");
        }
        IERC20(_token).safeTransfer(
            _to,
            IERC20(_token).balanceOf(address(this))
        );
    }

    // ============ EXTERNAL FUNCTIONS - USER FLOWS ============

    /// @inheritdoc ISummerVestingWalletsEscrow
    function stakeVesting() public override nonReentrant {
        uint256 totalBalance;
        for (uint256 i = 0; i < _vestingFactories.length(); i++) {
            IMinimalVestingFactory vestingFactory = IMinimalVestingFactory(
                _vestingFactories.at(i)
            );
            /// @dev only the original owner of the vesting wallet can stake from it
            /// @dev if the ownership was transferred to the user - the user can't stake from it
            address vestingWallet = vestingFactory.vestingWallets(msg.sender);
            // if the vesting wallet address is not zero and the user has not staked from this vesting factory yet
            if (
                vestingWallet != address(0) &&
                !_userStakedVestingFactoriesBalance[msg.sender].contains(
                    address(vestingFactory)
                )
            ) {
                _validateVestingWalletOwner(vestingWallet);
                uint256 balance = SUMMER_TOKEN.balanceOf(vestingWallet);
                uint256 released = IMinimalVestingWallet(vestingWallet)
                    .released(address(SUMMER_TOKEN));
                _userStakedVestingFactoriesBalance[msg.sender].set(
                    address(vestingFactory),
                    balance
                );
                _userStakedVestingFactoriesReleased[msg.sender].set(
                    address(vestingFactory),
                    released
                );
                totalBalance += balance;
                emit StakedVestingWallet(
                    msg.sender,
                    address(vestingFactory),
                    balance,
                    released
                );
            }
        }

        if (totalBalance > 0) {
            STAKED_SUMMER_TOKEN.mint(msg.sender, totalBalance);
        } else {
            revert Staking_VestingWalletsEmpty();
        }
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function unstakeVesting() public override nonReentrant {
        uint256 totalBalance;
        while (_userStakedVestingFactoriesBalance[msg.sender].length() > 0) {
            (
                address factory,
                uint256 stakedBalance
            ) = _userStakedVestingFactoriesBalance[msg.sender].at(
                    _userStakedVestingFactoriesBalance[msg.sender].length() - 1
                );

            IMinimalVestingFactory vestingFactory = IMinimalVestingFactory(
                factory
            );
            address vestingWallet = vestingFactory.vestingWallets(msg.sender);

            if (vestingWallet != address(0)) {
                uint256 releasedAtUnstake = _unstakeVestingWallet(
                    vestingWallet,
                    vestingFactory
                );
                totalBalance += stakedBalance;
            }
            _userStakedVestingFactoriesBalance[msg.sender].remove(
                address(vestingFactory)
            );
            _userStakedVestingFactoriesReleased[msg.sender].remove(
                address(vestingFactory)
            );
            emit UnstakedVestingWallet(
                msg.sender,
                address(vestingFactory),
                stakedBalance,
                releasedAtUnstake
            );
        }
        if (totalBalance > 0) {
            STAKED_SUMMER_TOKEN.burnFrom(msg.sender, totalBalance);
        } else {
            revert Staking_NoVestingWalletsStaked();
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Internal method to unstake tokens from a single vesting wallet
     * @dev all or nothing - if user owns multiple vesting wallets - they can't unstake only from some of them
     * @param _vestingWallet The vesting wallet address
     * @param _vestingFactory The vesting factory address
     */
    function _unstakeVestingWallet(
        address _vestingWallet,
        IMinimalVestingFactory _vestingFactory
    ) internal returns (uint256 releasedAtUnstake) {
        _validateVestingWalletOwner(_vestingWallet);
        address originalOwner = _vestingFactory.vestingWalletOwners(
            _vestingWallet
        );

        uint256 releasedAtStake = _userStakedVestingFactoriesReleased[
            originalOwner
        ].get(address(_vestingFactory));
        releasedAtUnstake = IMinimalVestingWallet(_vestingWallet).released(
            address(SUMMER_TOKEN)
        );
        uint256 releasedWhileStaked = releasedAtUnstake - releasedAtStake;
        if (releasedWhileStaked > 0) {
            /// @dev `release()` method is permissionless - so it can be called by anyone
            /// @dev the tokens released while staked are transferred back to the original owner
            SUMMER_TOKEN.safeTransfer(originalOwner, releasedWhileStaked);
        }
        IMinimalVestingWallet(_vestingWallet).transferOwnership(originalOwner);
    }

    /**
     * @dev Internal method to validate the owner of a vesting wallet is the escrow
     * @param _vestingWallet The vesting wallet address
     */
    function _validateVestingWalletOwner(address _vestingWallet) internal view {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking__InvalidOwner("Vesting wallet not owned by escrow");
        }
    }
}
