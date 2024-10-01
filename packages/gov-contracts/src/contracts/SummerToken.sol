pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {ISummerToken} from "../interfaces/ISummerToken.sol";

import {SummerVestingWallet} from "./SummerVestingWallet.sol";

contract SummerToken is
    OFT,
    ERC20Burnable,
    ERC20Votes,
    ERC20Permit,
    ISummerToken
{
    uint256 private constant INITIAL_SUPPLY = 1e9;
    mapping(address owner => address vestingWallet) public vestingWallets;

    constructor(
        TokenParams memory params
    )
        OFT(params.name, params.symbol, params.lzEndpoint, params.governor)
        ERC20Permit(params.name)
        Ownable(params.governor)
    {}

    /**
     * @dev Creates a new vesting wallet for a beneficiary
     * @param beneficiary Address of the beneficiary to whom vested tokens are transferred
     * @param amount Amount of tokens to be vested
     * @param vestingType Type of vesting schedule. See VestingType for options.
     */
    function createVestingWallet(
        address beneficiary,
        uint256 amount,
        SummerVestingWallet.VestingType vestingType
    ) external {
        if (vestingWallets[beneficiary] != address(0)) {
            revert VestingWalletAlreadyExists(beneficiary);
        }

        uint64 startTimestamp = uint64(block.timestamp);
        uint64 durationSeconds = 0;
        if (vestingType == SummerVestingWallet.VestingType.SixMonthCliff) {
            durationSeconds = 180 days;
        } else if (
            vestingType == SummerVestingWallet.VestingType.TwoYearQuarterly
        ) {
            durationSeconds = 730 days;
        } else {
            revert InvalidVestingType(vestingType);
        }

        address newVestingWallet = address(
            new SummerVestingWallet(
                beneficiary,
                startTimestamp,
                durationSeconds,
                vestingType
            )
        );
        vestingWallets[beneficiary] = newVestingWallet;

        _transfer(msg.sender, newVestingWallet, amount);
    }

    /*
     * @dev Overrides the nonces function to resolve conflicts between ERC20Permit and Nonces.
     * @param owner The address to check nonces for.
     * @return The current nonce for the given address.
     */
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /*
     * @dev Internal function to update token balances.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    )
        internal
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        (amountSentLD, amountReceivedLD) = _debitView(
            _amountLD,
            _minAmountLD,
            _dstEid
        );

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Override to include all user tokens in voting power - including locked up tokens
     * @param account The address to get voting units for
     * @return The number of voting units for the account
     */
    function _getVotingUnits(
        address account
    ) internal view override returns (uint256) {
        uint256 directBalance = balanceOf(account);
        address vestingWalletAddress = vestingWallets[account];

        if (vestingWalletAddress != address(0)) {
            uint256 vestingWalletBalance = balanceOf(vestingWalletAddress);
            return directBalance + vestingWalletBalance;
        }

        return directBalance;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Error thrown when attempting to create a vesting wallet for an address that already has one
     * @param beneficiary The address for which a vesting wallet already exists
     */
    error VestingWalletAlreadyExists(address beneficiary);

    /**
     * @dev Error thrown when an invalid vesting type is provided
     * @param invalidType The invalid vesting type that was provided
     */
    error InvalidVestingType(SummerVestingWallet.VestingType invalidType);
}
