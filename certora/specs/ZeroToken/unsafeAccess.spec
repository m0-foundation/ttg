import "setup.spec";

rule unsafeAccessRevert_votingPowers(address account, uint256 index) {
    require index < getVotingPowersLength(account);
    /// Safe
    votingPowers@withrevert(account, index);
    bool safeReverted = lastReverted;
    /// Unsafe
    unsafeAccessVotingPowers@withrevert(account, index);
    bool unsafeReverted = lastReverted;

    assert unsafeReverted <=> safeReverted;
}

rule unsafeAccessRevert_delegatees(address account, uint256 index) {
    require index < getDelegateessLength(account);
    /// Safe
    delegatees@withrevert(account, index);
    bool safeReverted = lastReverted;
    /// Unsafe
    unsafeAccessDelegatees@withrevert(account, index);
    bool unsafeReverted = lastReverted;

    assert unsafeReverted <=> safeReverted;
}

rule unsafeAccessEquivalence_votingPowers(address account, uint256 index) {
    /// Safe
    EpochBasedVoteToken.AmountSnap snapA = votingPowers(account, index);
    /// Unsafe
    EpochBasedVoteToken.AmountSnap snapB = unsafeAccessVotingPowers(account, index);

    assert snapA.startingEpoch == snapB.startingEpoch && snapA.amount == snapB.amount;
}

rule unsafeAccessEquivalence_delegatees(address account, uint256 index) {
    /// Safe
    EpochBasedVoteToken.AccountSnap snapA = delegatees(account, index);
    /// Unsafe
    EpochBasedVoteToken.AccountSnap snapB = unsafeAccessDelegatees(account, index);

    assert snapA.startingEpoch == snapB.startingEpoch && snapA.account == snapB.account;
}
