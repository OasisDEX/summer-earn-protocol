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
 * @notice Escrow staking that mints xSUMR against SUMR balances held in vesting wallets.
 * @dev Core principles:
 *      - Users can stake governance power (xSUMR) against SUMR held in vesting wallets already owned by the escrow.
 *      - On stake: record vesting SUMR balance and `released` snapshot, then mint xSUMR 1:1 to the user.
 *      - On unstake: forward any SUMR released while staked to the user and transfer wallet ownership back; burn xSUMR.
 *      - The escrow does not move SUMR out of vesting wallets, only forwards released amounts at exit.
 *      - Vesting factories are allowlisted by governance to constrain integrations.
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
        // Basic address validation to avoid footguns at deployment
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

        // Seed allowlist from constructor input
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
        // Governance-controlled: expand integration surface area
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
        // Governance-controlled: reduce integration surface area
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
        // Emergency-only: return vesting wallet ownership to a specified address
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
        // Sweep arbitrary ERC20 tokens sitting on the escrow
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
    function stakeVesting(
        address[] calldata factories
    ) public override nonReentrant {
        // Loop over requested factories and perform per-factory stake
        for (uint256 i = 0; i < factories.length; i++) {
            if (!_vestingFactories.contains(factories[i])) {
                revert Staking_FactoryNotEnabled();
            }
            _stakeFromFactory(IMinimalVestingFactory(factories[i]), msg.sender);
        }
    }

    /// @inheritdoc ISummerVestingWalletsEscrow
    function unstakeVesting(
        address[] calldata factories
    ) public override nonReentrant {
        // Process requested factories independently to allow partial exits
        for (uint256 i = 0; i < factories.length; i++) {
            _unstakeFromFactory(
                IMinimalVestingFactory(factories[i]),
                msg.sender
            );
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @notice Stakes against a single vesting factory for `_user`, minting xSUMR equal to the vesting wallet SUMR balance.
     * @dev Requirements and side-effects:
     *      - Factory must be enabled externally via `addVestingFactory`
     *      - The escrow MUST already be the owner of the user's vesting wallet
     *      - Records the vesting wallet SUMR `balance` and `released` snapshot for later reconciliation
     *      - Emits `StakedVestingWallet(user, factory, balance, released)`
     *      - Mints xSUMR 1:1 to the user for the recorded `balance`
     *      - If the users vesting wallet received additional SUMR tokens before staking on top of vesting schedule,
     *        they will get additional xSUMR tokens
     * @param _vestingFactory The vesting factory implementation to resolve the user's vesting wallet
     * @param _user The user performing the stake
     * @custom:reverts Staking_FactoryAlreadyStaked If the user already staked this factory
     * @custom:reverts Staking_InvalidAddress If the vesting wallet cannot be resolved
     * @custom:reverts Staking_InvalidOwner If the escrow is not the current owner of the vesting wallet
     * @custom:reverts Staking_ZeroBalance If the vesting wallet SUMR balance is zero
     */
    function _stakeFromFactory(
        IMinimalVestingFactory _vestingFactory,
        address _user
    ) internal {
        // Prevent double-staking same factory to preserve invariant on accounting maps
        address factoryAddress = address(_vestingFactory);
        if (
            _userStakedVestingFactoriesBalance[_user].contains(factoryAddress)
        ) {
            revert Staking_FactoryAlreadyStaked();
        }

        // Resolve vesting wallet and validate escrow ownership
        // vestingWallets map can't be modified, always keeps the original owner
        address vestingWallet = _vestingFactory.vestingWallets(_user);
        if (vestingWallet == address(0)) {
            revert Staking_InvalidAddress("Vesting wallet not found");
        }

        _validateVestingWalletOwner(vestingWallet);

        // Snapshot SUMR balance and released amount at time of stake
        uint256 balance = SUMMER_TOKEN.balanceOf(vestingWallet);
        if (balance == 0) {
            revert Staking_ZeroBalance();
        }
        uint256 released = IMinimalVestingWallet(vestingWallet).released(
            address(SUMMER_TOKEN)
        );

        // Persist stake metadata for this user/factory pair
        _userStakedVestingFactoriesBalance[_user].set(factoryAddress, balance);
        _userStakedVestingFactoriesReleased[_user].set(
            factoryAddress,
            released
        );

        // Mint governance power (xSUMR) equal to vesting wallet SUMR balance
        STAKED_SUMMER_TOKEN.mint(_user, balance);

        emit StakedVestingWallet(_user, factoryAddress, balance, released);
    }

    /**
     * @notice Unstakes a previously staked vesting position for `_user` and `_vestingFactory`.
     * @dev Side-effects:
     *      - Computes tokens released while staked and transfers them back to the user
     *      - Transfers vesting wallet ownership from escrow back to the user
     *      - Burns xSUMR equal to recorded staked balance
     *      - Cleans recorded balance and released snapshots for the user/factory pair
     *      - Emits `UnstakedVestingWallet(user, factory, stakedBalance, releasedAtUnstake)`
     * @param _vestingFactory The vesting factory implementation to resolve the user's vesting wallet
     * @param _user The user performing the unstake
     * @custom:reverts Staking_NoStakeForFactory If the user has no stake for this factory
     * @custom:reverts Staking_InvalidAddress If the vesting wallet cannot be resolved
     * @custom:reverts Staking_InvalidOwner If the escrow is not the current owner of the vesting wallet
     */
    function _unstakeFromFactory(
        IMinimalVestingFactory _vestingFactory,
        address _user
    ) internal {
        // Ensure the user has an active stake for this factory
        address factoryAddress = address(_vestingFactory);
        if (
            !_userStakedVestingFactoriesBalance[_user].contains(factoryAddress)
        ) {
            revert Staking_NoStakeForFactory();
        }

        // Load stake state and resolve vesting wallet
        uint256 stakedBalance = _userStakedVestingFactoriesBalance[_user].get(
            factoryAddress
        );

        address vestingWallet = _vestingFactory.vestingWallets(_user);
        if (vestingWallet == address(0)) {
            revert Staking_InvalidAddress("Vesting wallet not found");
        }

        _validateVestingWalletOwner(vestingWallet);

        // Compute and forward the amount released while staked (permissionless release may be called externally)
        uint256 releasedAtStake = _userStakedVestingFactoriesReleased[_user]
            .get(address(_vestingFactory));
        uint256 releasedAtUnstake = IMinimalVestingWallet(vestingWallet)
            .released(address(SUMMER_TOKEN));
        uint256 releasedWhileStaked = releasedAtUnstake - releasedAtStake;
        if (releasedWhileStaked > 0) {
            /// @dev `release()` method is permissionless; it can be called by anyone.
            /// @dev the tokens released while staked are transferred back to the original owner
            SUMMER_TOKEN.safeTransfer(_user, releasedWhileStaked);
        }
        // Transfer vesting wallet ownership back to the user
        IMinimalVestingWallet(vestingWallet).transferOwnership(_user);

        // Clear stake state for this user/factory and burn xSUMR matching recorded balance
        _userStakedVestingFactoriesBalance[_user].remove(factoryAddress);
        _userStakedVestingFactoriesReleased[_user].remove(factoryAddress);

        STAKED_SUMMER_TOKEN.burnFrom(_user, stakedBalance);

        emit UnstakedVestingWallet(
            _user,
            factoryAddress,
            stakedBalance,
            releasedAtUnstake
        );
    }

    /**
     * @notice Validates that the escrow currently owns a vesting wallet.
     * @param _vestingWallet The vesting wallet address to check
     * @custom:reverts Staking_InvalidOwner If the vesting wallet owner is not this escrow
     */
    function _validateVestingWalletOwner(address _vestingWallet) internal view {
        if (IMinimalVestingWallet(_vestingWallet).owner() != address(this)) {
            revert Staking_InvalidOwner("Vesting wallet not owned by escrow");
        }
    }
}
