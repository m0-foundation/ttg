import "setup.spec";
import "../VoteTokenStorageMirror.spec";

use rule mirrorIntegrity;
use invariant FutureEpochsAreNullified;
use invariant EpochsAreNotInTheFuture;
use invariant DelegatesEpochsAreMonotonic;
use invariant BalancesEpochsAreMonotonic;
use invariant BalanceLengthExceedsDelegateesLength;
use invariant TotalSuppliesEpochsAreMonotonic;
use invariant MirrorLengths;

/// @title The latest starting epoch for every account-specific array is at most the current epoch.
invariant LatestEpochIsAtMostCurrentEpoch(env e, address account) 
    e.block.timestamp <= MAX_TIMESTAMP() => (
        (getBalancesLength(account) > 0 => 
            balances(account, assert_uint256(getBalancesLength(account) - 1)).startingEpoch <= assert_uint16(clock(e))) &&
        (getDelegateessLength(account) > 0 => 
            delegatees(account, assert_uint256(getDelegateessLength(account) - 1)).startingEpoch <= assert_uint16(clock(e))) &&
        (getVotingPowersLength(account) > 0 => 
            votingPowers(account, assert_uint256(getVotingPowersLength(account) - 1)).startingEpoch <= assert_uint16(clock(e)))
    )
    {
        preserved with (env eP) {
            requireInvariant BootstrapEpochIsInThePast(eP);
            require eP.block.timestamp == e.block.timestamp;
        }
    }

/// @title The participation inflation is bounded by 100%.
invariant ParticipationInflationBound()
    participationInflation() <= ONE();

/// @title The bootstrap epoch is always in the past.
invariant BootstrapEpochIsInThePast(env e)
    PostBootstrap(e);

/// @title The starting epochs of voting powers array elements are strictly monotonic.
invariant VotingEpochsAreMonotonic(address account)
    (votingPowersLength[account] > 0 => balancesLength[account] > 0) 
    &&
    (forall uint256 index1. forall uint256 index2. 
    (
        index1 < votingPowersLength[account] &&
        index2 < votingPowersLength[account] &&
        index1 < index2
    ) =>
    userVotingPowerEpochs[account][index1] < userVotingPowerEpochs[account][index2])
    &&
    (
        forall uint256 index. index >= votingPowersLength[account] => userVotingPowerEpochs[account][index] == 0
    )
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant MirrorLengths(account);
            delegateeCounter = 0;
            requireInvariant VotingEpochsAreMonotonic(delegateesList(0));
            requireInvariant VotingEpochsAreMonotonic(delegateesList(1));
            requireInvariant VotingEpochsAreMonotonic(delegateesList(2));
            requireInvariant AllDelegateesHaveSynched();
            /// Need to think how to prove:
            require balancesLength[delegateesList(0)] > 0;
            require balancesLength[delegateesList(1)] > 0;
            require balancesLength[delegateesList(2)] > 0;
        }
    }

/// @title All delegates ever have synched at least once.
invariant AllDelegateesHaveSynched()
    forall address account. forall address delegatee. forall uint16 epoch.
        (delegatee == allDelegatees[account][epoch] && delegatee !=0) =>
        balancesLength[delegatee] > 0
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant BootstrapEpochIsInThePast(e);
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
        }
    }

/// @title For every account, the length of the last syncs array cannot exceed the length of balances array. 
invariant BalanceLengthExceedsParticipationLength(address account)
    getParticipationsLength(account) <= getBalancesLength(account) &&
    (
        (getParticipationsLength(account) == getBalancesLength(account) && getParticipationsLength(account) > 0) =>
        participationsEpochs[account][assert_uint256(getParticipationsLength(account) - 1)] ==
        userBalancesEpochs[account][assert_uint256(getParticipationsLength(account) - 1)]
    )
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = require_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant BootstrapEpochIsInThePast(e);
            requireInvariant MirrorLengths(account);
        }
    }

invariant DelegateeIsNotZero(address account)
    forall uint256 index. index < delegateesLength[account] =>
    allDelegatees[account][userDelegateesEpochs[account][index]] !=0
    {
        preserved with (env e) {
            require e.msg.sender != 0;
            requireInvariant DelegateeIsNotZero(e.msg.sender);
            requireInvariant MirrorLengths(account);
        }
        preserved delegateBySig(address account_, address delegatee_, uint256 nonce_, uint256 expiry_, bytes signature_) with (env e) {
            require account_ !=0;
            require e.msg.sender != 0;
            requireInvariant DelegateeIsNotZero(e.msg.sender);
            requireInvariant MirrorLengths(account);
        }
    }

/// @title The starting epochs of the last syncs array are never in the future.
invariant EpochsAreNotInTheFuture_extended(env e, uint16 currentEpoch)
    currentEpoch == assert_uint16(clock(e)) && e.block.timestamp <= MAX_TIMESTAMP() =>
    (
        forall address account. forall uint256 index. 
        participationsEpochs[account][index] <= currentEpoch
    )
    {
        preserved with (env eP) {require e.block.timestamp == eP.block.timestamp;}
    }

/// @title All user-specific arrays starting epochs are the bootstrap epoch at minimum.
invariant EpochsAreAfterBootstrap(address account, uint16 epoch)
    epoch == bootstrapEpoch() => 
    (
        forall uint256 index .
        (index < balancesLength[account] => userBalancesEpochs[account][index] >= epoch) &&
        (index < delegateesLength[account] => userDelegateesEpochs[account][index] >= epoch) &&
        (index < votingPowersLength[account] => userVotingPowerEpochs[account][index] >= epoch)
    )
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            requireInvariant MirrorLengths(account);
            requireInvariant BootstrapEpochIsInThePast(e);
        }
    }

/// @title The past votes for any account are immutable.
rule pastVotesAreImmutable(address account, uint16 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    require epoch < currentEpoch;

    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant BalancesEpochsAreMonotonic(account);
    requireInvariant DidntParticipateBeforeBootstrap(account, 1);
    requireInvariant DidntParticipateBeforeBootstrap(account, 2);
    requireInvariant MirrorLengths(account);

    uint256 votesBefore = getPastVotes(e, account, epoch);
        calldataarg args;
        f(e, args);
    uint256 votesAfter = getPastVotes(e, account, epoch);
    
    assert votesBefore == votesAfter;
}

/// @title The past votes for any account are immutable.
rule pastDelegatesAreImmutable(address account, uint16 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    require epoch < currentEpoch;

    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant BalancesEpochsAreMonotonic(account);
    requireInvariant DelegatesEpochsAreMonotonic(account);
    requireInvariant NoDelegateeIfNoSyncs(e, account);
    requireInvariant DidntParticipateBeforeBootstrap(account, 1);
    requireInvariant DidntParticipateBeforeBootstrap(account, 2);
    requireInvariant MirrorLengths(account);

    address delegateBefore = pastDelegates(e, account, epoch);
        calldataarg args;
        f(e, args);
    address delegateAfter = pastDelegates(e, account, epoch);
    
    assert delegateBefore == delegateAfter;
}

/// @title The past unrealized inflation for any account are immutable.
rule pastUnrealizedInflationIsImmutable(address account, uint16 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    require epoch < currentEpoch;
    require epoch > bootstrapEpoch();
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(account, bootstrapEpoch());
    requireInvariant BalanceLengthExceedsDelegateesLength(account);
    requireInvariant BalanceLengthExceedsParticipationLength(account);
    requireInvariant DidntParticipateBeforeBootstrap(account, epoch);
    requireInvariant MirrorLengths(account);

    uint240 inflation_before = getUnrealizedInflation(e, account, epoch);
        calldataarg args;
        f(e, args);
    uint240 inflation_after = getUnrealizedInflation(e, account, epoch);
    
    assert inflation_before == inflation_after;
}

/// @title The past total supplies are immutable.
rule pastTotalSupplyIsImmutable(uint256 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    require epoch < assert_uint256(currentEpoch);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);

    uint256 supply_before = pastTotalSupply(e, epoch);
        calldataarg args;
        f(e, args);
    uint256 supply_after = pastTotalSupply(e, epoch);

    assert supply_before == supply_after;
}
 
/// @title The past balances for any account are immutable.
rule pastBalanceIsImmutable(address account, uint16 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    require epoch < currentEpoch;
    require epoch > bootstrapEpoch();
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(account, bootstrapEpoch());
    requireInvariant NoDelegateeIfNoSyncs(e, account);
    requireInvariant BalanceLengthExceedsParticipationLength(account);
    requireInvariant BalanceLengthExceedsDelegateesLength(account);
    requireInvariant MirrorLengths(account);

    uint256 balance_before = pastBalanceOf(e, account, epoch);
        calldataarg args;
        f(e, args);
    uint256 balance_after = pastBalanceOf(e, account, epoch);

    assert balance_before == balance_after;
}

/// @title No account has participated before the bootstrap epoch
invariant DidntParticipateBeforeBootstrap(address account, uint16 epoch)
    epoch ==0 ? true : 
    (epoch <= bootstrapEpoch() => !hasParticipatedAt(account, epoch))
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e)); 
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant BootstrapEpochIsInThePast(e);
        }
    }

invariant LastDelegateIsPresentDelegate(env e, address account)
    delegateesLength[account] > 0 => delegates(e, account) == lastDelegate[account]
    {
        preserved with (env eP) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e)); 
            require eP.block.timestamp == e.block.timestamp;
            requireInvariant LastDelegateIsPresentDelegate(eP, account);
            requireInvariant LastDelegateIsPresentDelegate(eP, eP.msg.sender);
            requireInvariant DelegatesEpochsAreMonotonic(account);
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant BalanceLengthExceedsDelegateesLength(account);
            requireInvariant MirrorLengths(account);
        }
    }

/// @title Marking participation for a user doesn't change the balance or power of another user.
/// Verified
rule markParticipationIsUserIndependent(address account) {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    address accountA;
    require accountA != account;
    uint256 balance_before = balanceOf(e, account);
    uint256 votes_before = getVotes(e, account);
        markParticipation(e, accountA);
    uint256 balance_after = balanceOf(e, account);
    uint256 votes_after = getVotes(e, account);

    assert votes_before == votes_after;
    assert balance_before == balance_after;
}

/// @title markParticipation() success is user-independent.
rule markParticipationSucceesIsUserIndependent(address accountA, address accountB) {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    require accountA != accountB;
    storage initState = lastStorage;

    uint16 currentEpoch = assert_uint16(clock(e)); 
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(accountA, bootstrapEpoch());
    requireInvariant NoDelegateeIfNoSyncs(e, accountA);
    requireInvariant NoDelegateeIfNoSyncs(e, accountB);
    requireInvariant MirrorLengths(accountA);
    requireInvariant MirrorLengths(accountB);

    uint256 votesA = getVotes(e, accountA);
    uint256 bootstrapA = assert_uint256(bootstrapBalanceMock(accountA, bootstrapEpoch()));
    uint256 votesB = getVotes(e, accountB);
    uint256 bootstrapB = assert_uint256(bootstrapBalanceMock(accountB, bootstrapEpoch()));
    uint256 votesToSumA = votesA > bootstrapA ? votesA : bootstrapA;
    uint256 votesToSumB = votesB > bootstrapB ? votesB : bootstrapB;
    /// We assume no overflow.
    require totalSupply(e) + votesToSumA + votesToSumB <= max_uint240;

    markParticipation(e, accountA) at initState;

    markParticipation(e, accountB) at initState;
    markParticipation@withrevert(e, accountA);
    
    assert !lastReverted;
}

/// @title transfer() doesn't increase the balance of the sender.
rule transferDoesntIncreaseBalanceOfSender(address recipient, uint256 amount) {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    require e.msg.sender != currentContract;
    
    uint16 currentEpoch = assert_uint16(clock(e)); 
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant BalanceLengthExceedsParticipationLength(recipient);
    requireInvariant BalanceLengthExceedsParticipationLength(e.msg.sender);
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(recipient, bootstrapEpoch());
    requireInvariant EpochsAreAfterBootstrap(e.msg.sender, bootstrapEpoch());
    requireInvariant NoDelegateeIfNoSyncs(e, e.msg.sender);
    requireInvariant MirrorLengths(recipient);
    requireInvariant MirrorLengths(e.msg.sender);

    mathint balanceBefore = balanceOf(e, e.msg.sender);
        transfer(e, recipient, amount);
    mathint balanceAfter = balanceOf(e, e.msg.sender);

    assert balanceBefore >= balanceAfter;
}

rule synchingDoesntChangeBalance(address account) {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e)); 
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant ParticipationInflationBound();
    requireInvariant BalanceLengthExceedsParticipationLength(account);
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(account, bootstrapEpoch());
    requireInvariant NoDelegateeIfNoSyncs(e, account);
    requireInvariant MirrorLengths(account);
    requireInvariant DelegatesEpochsAreMonotonic(account);
    requireInvariant BalanceLengthExceedsDelegateesLength(account);
    requireInvariant VotingEpochsAreMonotonic(account);

    uint256 balanceBefore = balanceOf(e, account);
        calldataarg args;
        sync(e, args);
    uint256 balanceAfter = balanceOf(e, account);

    assert balanceBefore == balanceAfter;
}

/// @title For any account, the delegatees at epochs after the last sync epochs are zero.
invariant NoPastDelegatesAtUnsync(env e, address account, uint16 epoch)
    (getBalancesLength(account) == 0 => getDelegateessLength(account) == 0) 
    && 
    (
        epoch >= require_uint16(clock(e)) ? true : (
        (getBalancesLength(account) > 0 => 
            (epoch > balances(account, require_uint256(getBalancesLength(account)-1)).startingEpoch =>
            pastDelegates(e, account, epoch) == 0))
    ))
    {
        preserved with (env eP) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            require eP.block.timestamp <= MAX_TIMESTAMP();
            requireInvariant NoPastDelegatesAtUnsync(eP, account, epoch);
        }
    }

/// @title For every account, its delegatee has no participations if there were not syncs for that account.
invariant NoDelegateeIfNoSyncs(env e, address account)
    getBalancesLength(account) == 0 => delegates(e,account) == 0
    &&
    getParticipationsLength(0) == 0
    {
        preserved with (env eP) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            require eP.block.timestamp == e.block.timestamp;
            address delegatee = delegates(e, account);
            requireInvariant BalanceLengthExceedsParticipationLength(delegatee);
            requireInvariant BalanceLengthExceedsParticipationLength(account);
        }
        preserved delegate(address delegatee) with (env eP) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            require eP.block.timestamp == e.block.timestamp;
            requireInvariant BalanceLengthExceedsParticipationLength(delegatee);
            requireInvariant BalanceLengthExceedsParticipationLength(account);
        }
        preserved markParticipation(address delegatee) with (env eP) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            require eP.block.timestamp == e.block.timestamp;
            /// We assume the zero address cannot be marked as participated, due to
            /// e.msg.sender !=0 and message signers are not zero address.
            require delegatee != 0;
            requireInvariant BalanceLengthExceedsParticipationLength(delegatee);
            requireInvariant BalanceLengthExceedsParticipationLength(account);
        }
    }

/// @title Only buying can change the amount to auction in the same epoch.
rule onlyBuyingCanChangeTheEpochSpecificAuctionAmount(method f) filtered{f -> !f.isView
&& f.selector != sig:buy(uint256,uint256,address,uint16).selector} {
    env e1;
    env e2;
    require e1.block.timestamp <= MAX_TIMESTAMP();
    uint16 currentEpoch = assert_uint16(clock(e1)); 
    require currentEpoch == require_uint16(clock(e2));
    requireInvariant EpochsAreNotInTheFuture_extended(e1, currentEpoch);
    uint240 amount_before = amountToAuction(e1);
        calldataarg args;
        f(e2, args);
    uint240 amount_after = amountToAuction(e2);

    assert amount_before == amount_after;
}

rule delegatingPreservesVotingPower(address delegatee) {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    address old_delegatee = delegates(e, e.msg.sender);
    uint16 currentEpoch = assert_uint16(clock(e));

    /// delegatee = 0 is effectively setting the delegation back to the delegator. 
    address actualDelegatee = delegatee == 0 ? e.msg.sender : delegatee;
    requireInvariant DelegateeIsNotZero(e.msg.sender);
    requireInvariant BootstrapEpochIsInThePast(e);
    requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
    requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
    requireInvariant EpochsAreAfterBootstrap(actualDelegatee, bootstrapEpoch());
    requireInvariant LatestEpochIsAtMostCurrentEpoch(e, actualDelegatee);
    requireInvariant VotingEpochsAreMonotonic(actualDelegatee);
    requireInvariant BalancesEpochsAreMonotonic(actualDelegatee);
    requireInvariant NoDelegateeIfNoSyncs(e, e.msg.sender);
    requireInvariant BalanceLengthExceedsParticipationLength(actualDelegatee);
    requireInvariant DidntParticipateBeforeBootstrap(old_delegatee, require_uint16(currentEpoch - 1));
    requireInvariant DidntParticipateBeforeBootstrap(delegatee, require_uint16(currentEpoch - 1));
    requireInvariant EpochsAreAfterBootstrap(old_delegatee, bootstrapEpoch());
    requireInvariant LatestEpochIsAtMostCurrentEpoch(e, old_delegatee);
    requireInvariant VotingEpochsAreMonotonic(old_delegatee);
    requireInvariant BalancesEpochsAreMonotonic(old_delegatee);
    requireInvariant BalanceLengthExceedsParticipationLength(old_delegatee);
    requireInvariant MirrorLengths(actualDelegatee);
    requireInvariant MirrorLengths(old_delegatee);

    mathint votes_before = getVotes(e, actualDelegatee) + getVotes(e, old_delegatee);
    require votes_before <= max_uint240;
    uint256 totalSupply_before = totalSupply(e);
        delegate(e, delegatee);
    mathint votes_after = getVotes(e, actualDelegatee) + getVotes(e, old_delegatee);
    uint256 totalSupply_after = totalSupply(e);

    assert totalSupply_after == totalSupply_before;
    assert votes_after == votes_before;
}
