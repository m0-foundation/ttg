import "setup.spec";
import "unsafeAccess.spec";
import "../VoteTokenStorageMirror.spec";

use rule mirrorIntegrity;
use builtin rule sanity;
use rule unsafeAccessRevert_votingPowers;
use rule unsafeAccessRevert_delegatees;
use rule unsafeAccessEquivalence_votingPowers;
use rule unsafeAccessEquivalence_delegatees;
use invariant FutureEpochsAreNullified;
use invariant EpochsAreNotInTheFuture;
use invariant DelegatesEpochsAreMonotonic;
use invariant BalancesEpochsAreMonotonic;
use invariant TotalSuppliesEpochsAreMonotonic;
use invariant MirrorLengths;
use invariant BootstrapEpochIsInThePast filtered{f -> f.isView}
use invariant EpochsAreNotInTheFuture_extended filtered{f -> f.isView}

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
            require eP.block.timestamp == e.block.timestamp;
        }
    }

/// @title The total supply of zero tokens is never zero.
/// Is preserved, but can be violated in the constructor if an empty array of minted addresses is passed.
rule totalSupplyIsNonZero(env e, method f) filtered{f -> !f.isView} {
    require e.block.timestamp <= MAX_TIMESTAMP();
    require totalSupply(e) > 0;
        calldataarg args;
        f(e, args);
    assert totalSupply(e) > 0;
}

/// @title The starting epochs of voting powers array elements are strictly monotonic.
invariant VotingEpochsAreMonotonic(address account)
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
            counter = 0;
            requireInvariant VotingEpochsAreMonotonic(delegateesList(0));
            requireInvariant VotingEpochsAreMonotonic(delegateesList(1));
            requireInvariant VotingEpochsAreMonotonic(delegateesList(2));
        }
    }

rule pastTotalSupplyIsImmutable(uint256 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    require epoch < assert_uint256(clock(e));

    uint256 supply_before = pastTotalSupply(e, epoch);
        calldataarg args;
        f(e, args);
    uint256 supply_after = pastTotalSupply(e, epoch);

    assert supply_before == supply_after;
}
 
rule pastBalanceIsImmutable(address account, uint256 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    require epoch < assert_uint256(clock(e));

    uint256 balance_before = pastBalanceOf(e, account, epoch);
        calldataarg args;
        f(e, args);
    uint256 balance_after = pastBalanceOf(e, account, epoch);

    assert balance_before == balance_after;
}

rule pastDelegateeIsImmutable(address account, uint256 epoch, method f) filtered{f -> !f.isView} {
    env e;
    require e.block.timestamp <= MAX_TIMESTAMP();
    require epoch < assert_uint256(clock(e));

    address delegate_before = pastDelegates(e, account, epoch);
        calldataarg args;
        f(e, args);
    address delegate_after = pastDelegates(e, account, epoch);

    assert delegate_before == delegate_after;
}

/// @title Minting tokens for different accounts cannot interfere each other.
rule mintingSuccessIsAccountIndependent(address account1, address account2) {
    env e1; uint256 amount1; 
        require e1.block.timestamp <= MAX_TIMESTAMP();
        uint16 epoch1 = assert_uint16(clock(e1));
    env e2; uint256 amount2;
        require e2.block.timestamp <= MAX_TIMESTAMP(); 
        uint16 epoch2 = assert_uint16(clock(e2));
    requireInvariant TotalSuppliesEpochsAreMonotonic();
    requireInvariant BalancesEpochsAreMonotonic(account1);
    requireInvariant BalancesEpochsAreMonotonic(account2);
    requireInvariant FutureEpochsAreNullified(e2, epoch2);
    requireInvariant EpochsAreNotInTheFuture(e2, epoch2);
    requireInvariant FutureEpochsAreNullified(e1, epoch1);
    requireInvariant EpochsAreNotInTheFuture(e1, epoch1);
    requireInvariant MirrorLengths(account1);
    /// Causality
    require e1.block.timestamp >= e2.block.timestamp;
    /// We consider two different accounts
    require account1 != account2;
    /// We assume no-overflow.
    require totalSupply(e1) + amount1 + amount2 <= max_uint240;
    require totalSupply(e2) + amount1 + amount2 <= max_uint240;
    require balanceOf(e1, account1) + amount1 <= max_uint240;
    storage initState = lastStorage;

    mint(e1, account1, amount1) at initState;

    mint(e2, account2, amount2) at initState;
    mint@withrevert(e1, account1, amount1);

    assert !lastReverted;
}

/// @title Different accounts balance post-mint is indepndent.
rule mintingAmountIsAccountIndependent(address account1, address account2) {
    env e1; uint256 amount1;
    env e2; uint256 amount2;
    storage initState = lastStorage;

    mint(e1, account1, amount1) at initState;
    uint256 balanceA = balanceOf(e1, account1);

    mint(e2, account2, amount2) at initState;
    mint(e1, account1, amount1);
    uint256 balanceB = balanceOf(e1, account1);

    assert account1 != account2 => balanceA == balanceB;
}
