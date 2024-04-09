definition MAX_EPOCH_PLUS() returns uint256 = (1 << 16);
definition MAX_LENGTH() returns uint256 = (1 << 128);

//  _____       _         _       
// |  __ \     | |       | |      
// | |  \/ ___ | |__  ___| |_ ___ 
// | | __ / _ \| '_ \/ __| __/ __|
// | |_\ \ (_) | | | \__ \ |_\__ \
//  \____/\___/|_| |_|___/\__|___/

ghost mapping(address => address) lastDelegate {
    init_state axiom forall address account . lastDelegate[account] == 0;
}

ghost mapping(address => mapping(uint256 => uint16)) userDelegateesEpochs {
    init_state axiom forall address user . forall uint256 index . userDelegateesEpochs[user][index] == 0;
}
ghost mapping(address => mapping(uint256 => uint16)) userVotingPowerEpochs {
    init_state axiom forall address user . forall uint256 index . userVotingPowerEpochs[user][index] == 0;
}
ghost mapping(address => mapping(uint256 => uint16)) userBalancesEpochs {
    init_state axiom forall address user . forall uint256 index . userBalancesEpochs[user][index] == 0;
}
ghost mapping(uint256 => uint16) totalSuppliesEpochs {
    init_state axiom forall uint256 index . totalSuppliesEpochs[index] == 0;
}

ghost mapping(address => uint256) balancesLength {
    init_state axiom forall address user . balancesLength[user] == 0;
    axiom forall address user . balancesLength[user] <= MAX_LENGTH();
}

ghost mapping(address => uint256) votingPowersLength {
    init_state axiom forall address user . votingPowersLength[user] == 0;
    axiom forall address user . votingPowersLength[user] <= MAX_LENGTH();
}

ghost mapping(address => uint256) delegateesLength {
    init_state axiom forall address user . delegateesLength[user] == 0;
    axiom forall address user . delegateesLength[user] <= MAX_LENGTH();
}

ghost uint256 totalSuppliesLength {
    init_state axiom totalSuppliesLength == 0;
    axiom totalSuppliesLength <= MAX_LENGTH();
}

// mapping from account => (epoch => amount)
ghost mapping(address => mapping(uint16 => uint240)) allBalances {
    init_state axiom forall address user . forall uint16 epoch . allBalances[user][epoch] == 0;
}

// mapping from account => (epoch => account)
ghost mapping(address => mapping(uint16 => address)) allDelegatees {
    init_state axiom forall address user . forall uint16 epoch . allDelegatees[user][epoch] == 0;
}

// mapping from account => (epoch => amount)
ghost mapping(address => mapping(uint16 => uint240)) allVotingPowers {
    init_state axiom forall address user . forall uint16 epoch . allVotingPowers[user][epoch] == 0;
}

ghost mapping(uint16 => mathint) sumOfBalancesPerEpoch {
    init_state axiom forall uint16 epoch . sumOfBalancesPerEpoch[epoch] == 0;
}

ghost mapping(uint16 => mathint) sumOfVotingPowerPerEpoch {
    init_state axiom forall uint16 epoch . sumOfVotingPowerPerEpoch[epoch] == 0;
}

//  _   _             _        
// | | | | ___   ___ | | _____ 
// | |_| |/ _ \ / _ \| |/ / __|
// |  _  | (_) | (_) |   <\__ \
// |_| |_|\___/ \___/|_|\_\___/

// Mirroring _votingPowers start //

hook Sload uint16 epoch _votingPowers[KEY address account][INDEX uint256 i].startingEpoch {
    require userVotingPowerEpochs[account][i] == epoch;
}

hook Sload uint240 amount _votingPowers[KEY address account][INDEX uint256 i].amount {
    uint16 epoch = userVotingPowerEpochs[account][i];
    require allVotingPowers[account][epoch] == amount;
}

hook Sstore _votingPowers[KEY address account][INDEX uint256 i].startingEpoch uint16 epoch (uint16 epoch_old) {
    require userVotingPowerEpochs[account][i] == epoch_old;
    userVotingPowerEpochs[account][i] = epoch;
}

hook Sstore _votingPowers[KEY address account][INDEX uint256 i].amount uint240 amount (uint240 amount_old) {
    uint16 epoch = userVotingPowerEpochs[account][i];
    allVotingPowers[account][epoch] = amount;
    sumOfVotingPowerPerEpoch[epoch] = sumOfVotingPowerPerEpoch[epoch] + amount - amount_old;
}

hook Sstore _votingPowers[KEY address account].(offset 0) uint256 length (uint256 length_old) {
    require length_old == votingPowersLength[account];
    votingPowersLength[account] = length;
}

// Mirroring _votingPowers end //

// Mirroring _balances start //

hook Sload uint16 epoch _balances[KEY address account][INDEX uint256 i].startingEpoch {
    require userBalancesEpochs[account][i] == epoch;
}

hook Sload uint240 amount _balances[KEY address account][INDEX uint256 i].amount {
    uint16 epoch = userBalancesEpochs[account][i];
    require allBalances[account][epoch] == amount;
}

hook Sstore _balances[KEY address account][INDEX uint256 i].startingEpoch uint16 epoch (uint16 epoch_old) {
    require userBalancesEpochs[account][i] == epoch_old;
    userBalancesEpochs[account][i] = epoch;
}

hook Sstore _balances[KEY address account][INDEX uint256 i].amount uint240 amount (uint240 amount_old) {
    uint16 epoch = userBalancesEpochs[account][i];
    allBalances[account][epoch] = amount;
    sumOfBalancesPerEpoch[epoch] = sumOfBalancesPerEpoch[epoch] + amount - amount_old;
}

hook Sload uint256 length _balances[KEY address account].(offset 0) {
    require length == balancesLength[account];
}

hook Sstore _balances[KEY address account].(offset 0) uint256 length (uint256 length_old) {
    require length_old == balancesLength[account];
    balancesLength[account] = length;
}

// Mirroring _balances end //

// Mirroring _delegatees start //

hook Sload uint16 _startingEpoch _delegatees[KEY address account][INDEX uint256 i].startingEpoch {
    require _startingEpoch == userDelegateesEpochs[account][i];
}

hook Sstore _delegatees[KEY address account][INDEX uint256 i].startingEpoch uint16 _startingEpoch {
    userDelegateesEpochs[account][i] = _startingEpoch;
}

hook Sload address _delegatee _delegatees[KEY address account][INDEX uint256 i].account {
    uint16 epoch = userDelegateesEpochs[account][i];
    require _delegatee == allDelegatees[account][epoch];
    require delegateesLength[account] - i == 1 => lastDelegate[account] == _delegatee;
}

hook Sstore _delegatees[KEY address account][INDEX uint256 i].account address _delegatee (address _delegatee_old) {
    uint16 epoch = userDelegateesEpochs[account][i];
    require allDelegatees[account][epoch] == _delegatee_old;
    allDelegatees[account][epoch] = _delegatee;
    if(delegateesLength[account] - i == 1) { 
        lastDelegate[account] = _delegatee;
    }
}

hook Sstore _delegatees[KEY address account].(offset 0) uint256 length (uint256 length_old) {
    require length_old == delegateesLength[account];
    delegateesLength[account] = length;
}
// Mirroring _delegatees end //

// Mirroring _totalSupplies start //

hook Sload uint16 _startingEpoch _totalSupplies[INDEX uint256 i].startingEpoch {
    require _startingEpoch == totalSuppliesEpochs[i];
}

hook Sstore _totalSupplies[INDEX uint256 i].startingEpoch uint16 _startingEpoch {
    totalSuppliesEpochs[i] = _startingEpoch;
}

hook Sstore _totalSupplies.(offset 0) uint256 length (uint256 length_old) {
    require length_old == totalSuppliesLength;
    totalSuppliesLength = length;
}
// Mirroring _totalSupplies end //

rule mirrorIntegrity(address account, uint16 indexA, uint16 indexB, uint16 indexC, uint16 indexD) {
    EpochBasedVoteToken.AmountSnap snapA = balances(account, indexA);
    EpochBasedVoteToken.AmountSnap snapB = votingPowers(account, indexB);
    EpochBasedVoteToken.AccountSnap snapC = delegatees(account, indexC);
    EpochBasedVoteToken.AmountSnap snapD = totalSupplies(indexD);

    assert snapA.startingEpoch == userBalancesEpochs[account][indexA];
    assert snapB.startingEpoch == userVotingPowerEpochs[account][indexB];
    assert snapC.startingEpoch == userDelegateesEpochs[account][indexC];
    assert snapD.startingEpoch == totalSuppliesEpochs[indexD];
    assert snapA.amount == allBalances[account][snapA.startingEpoch];
    assert snapB.amount == allVotingPowers[account][snapB.startingEpoch];
    assert snapC.account == allDelegatees[account][snapC.startingEpoch];
}

invariant MirrorLengths(address account)
    getBalancesLength(account) == balancesLength[account] &&
    getVotingPowersLength(account) == votingPowersLength[account] &&
    getDelegateessLength(account) == delegateesLength[account];

/// @title The starting epochs for balances, voting powers and delegatees arrays are never in the future.
invariant EpochsAreNotInTheFuture(env e, uint16 currentEpoch) 
    currentEpoch == assert_uint16(clock(e)) && e.block.timestamp <= MAX_TIMESTAMP() =>
    (
        forall address account. forall uint256 index. 
        userBalancesEpochs[account][index] <= currentEpoch && 
        userVotingPowerEpochs[account][index] <= currentEpoch &&
        userDelegateesEpochs[account][index] <= currentEpoch
    )
    &&
    (forall uint256 index. totalSuppliesEpochs[index] <= currentEpoch)
    {
        preserved with (env eP) {
            require e.block.timestamp == eP.block.timestamp;
            requireInvariant BootstrapEpochIsInThePast(eP);
        }
    }

invariant FutureEpochsAreNullified(env e, uint16 currentEpoch)
    currentEpoch == assert_uint16(clock(e)) && e.block.timestamp <= MAX_TIMESTAMP() =>
    (
        forall address account. forall uint16 epoch. 
        epoch > currentEpoch => 
        (allBalances[account][epoch] == 0 && allVotingPowers[account][epoch] == 0)
    )
    {
        preserved with (env eP) {
            require e.block.timestamp == eP.block.timestamp;
            requireInvariant EpochsAreNotInTheFuture(eP, currentEpoch);
            requireInvariant BootstrapEpochIsInThePast(eP);
        }
    }

/// @title The starting epochs of balances array elements are strictly monotonic.
invariant BalancesEpochsAreMonotonic(address account)
    forall uint256 index1. forall uint256 index2. 
    (
        index1 < balancesLength[account] &&
        index2 < balancesLength[account] &&
        index1 < index2
    ) =>
    userBalancesEpochs[account][index1] < userBalancesEpochs[account][index2]
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant MirrorLengths(account);
        }
    }

/// @title The starting epochs of delegatees array elements are strictly monotonic.
invariant DelegatesEpochsAreMonotonic(address account)
    (
    forall uint256 index1. forall uint256 index2. 
    (
        index1 < delegateesLength[account] &&
        index2 < delegateesLength[account] &&
        index1 < index2
    ) =>
    userDelegateesEpochs[account][index1] < userDelegateesEpochs[account][index2] )
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant BootstrapEpochIsInThePast(e);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant MirrorLengths(account);
        }
    }

/// @title The starting epochs of total supplies array elements are strictly monotonic.
invariant TotalSuppliesEpochsAreMonotonic()
    forall uint256 index1. forall uint256 index2. 
    (
        index1 < totalSuppliesLength &&
        index2 < totalSuppliesLength &&
        index1 < index2
    ) =>
    totalSuppliesEpochs[index1] < totalSuppliesEpochs[index2] 
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
        }
    }

/// @title For every account, the length of the delegatees array cannot exceed the length of balances array. 
invariant BalanceLengthExceedsDelegateesLength(address account)
    delegateesLength[account] <= balancesLength[account] && (
        (balancesLength[account] == delegateesLength[account] && delegateesLength[account] > 0) =>
        userDelegateesEpochs[account][assert_uint256(delegateesLength[account] - 1)] == 
        userBalancesEpochs[account][assert_uint256(balancesLength[account] - 1)]
    )
    {
        preserved with (env e) {
            require e.block.timestamp <= MAX_TIMESTAMP();
            uint16 currentEpoch = assert_uint16(clock(e));
            requireInvariant EpochsAreNotInTheFuture(e, currentEpoch);
            requireInvariant MirrorLengths(account);
            requireInvariant EpochsAreNotInTheFuture_extended(e, currentEpoch);
            requireInvariant BootstrapEpochIsInThePast(e);
        }
    }
