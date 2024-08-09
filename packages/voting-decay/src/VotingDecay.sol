// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IVotingDecay.sol";
import "./VotingDecayMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library VotingDecay {
    using VotingDecayMath for uint256;

    uint256 private constant SECONDS_PER_YEAR = 365 days;

    function calculateDecay(uint256 notionalAmount, uint256 elapsedTime) internal pure returns (uint256) {
        return notionalAmount.mulDiv(elapsedTime, SECONDS_PER_YEAR);
    }

    function getCurrentVotingPower(IVotingDecay.Account storage account) internal view returns (uint256) {
        if (account.delegate != address(0)) {
            return 0; // If delegated, the account itself has no voting power
        }

        uint256 elapsed = block.timestamp - account.lastUpdateTimestamp;
        uint256 decay = calculateDecay(account.votingPower, elapsed);
        return Math.max(account.votingPower - decay, 0);
    }

    function updateDecay(IVotingDecay.Account storage account) internal {
        if (account.delegate != address(0)) {
            return; // If delegated, no need to update decay
        }

        uint256 newVotingPower = getCurrentVotingPower(account);
        account.votingPower = newVotingPower;
        account.lastUpdateTimestamp = block.timestamp;

        emit IVotingDecay.DecayUpdated(address(this), newVotingPower);
    }

    function resetDecay(IVotingDecay.Account storage account) internal {
        account.lastUpdateTimestamp = block.timestamp;
        emit IVotingDecay.DecayReset(address(this));
    }

    function applyDecay(IVotingDecay.Account storage account) internal {
        updateDecay(account);
    }

    function setDecayRate(IVotingDecay.Account storage account, uint256 rate) internal {
        require(rate <= 1e18, "Decay rate must be <= 100%");
        account.decayRate = rate;
        emit IVotingDecay.DecayRateSet(address(this), rate);
    }

    function refreshDecay(IVotingDecay.Account storage account) internal {
        updateDecay(account);
        resetDecay(account);
    }

    function delegate(IVotingDecay.Account storage from, IVotingDecay.Account storage to) internal {
        require(from.delegate == address(0), "Already delegated");
        require(address(from) != address(to), "Cannot delegate to self");

        updateDecay(from);
        updateDecay(to);

        to.votingPower += from.votingPower;
        from.votingPower = 0;
        from.delegate = address(to);

        emit IVotingDecay.Delegated(address(from), address(to));
    }

    function undelegate(IVotingDecay.Account storage account) internal {
        require(account.delegate != address(0), "Not delegated");

        address delegateAddress = account.delegate;
        IVotingDecay.Account storage delegateAccount = IVotingDecay.Account(delegateAddress);

        updateDecay(delegateAccount);

        uint256 returnedVotingPower = getCurrentVotingPower(delegateAccount);
        delegateAccount.votingPower -= returnedVotingPower;
        account.votingPower = returnedVotingPower;
        account.delegate = address(0);
        account.lastUpdateTimestamp = block.timestamp;

        emit IVotingDecay.Undelegated(address(this));
    }
}
