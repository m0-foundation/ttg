import "setup.spec";
import "PowerTokenMock.spec";

use builtin rule sanity;

/// @title Any query of the past total supply / past votes satisfies epoch < current epoch = clock()
rule pastEpochIsNeverCurrentEpoch(method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    uint16 currentEpoch = assert_uint16(clock(e));
    latestPastEpoch = 0;
    calldataarg args;
    f(e, args);

    assert latestPastEpoch < currentEpoch;
}

invariant VoteStartIsNotInTheFarFuture(env e, uint256 proposalId)
    ValidTimeStamp(e) => voteStartPerProposal[proposalId] <= assert_uint16(clock(e) + votingDelay(e))
    {
        preserved with (env eP) {
            require e.block.timestamp == eP.block.timestamp;
            requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
        }
    }

invariant ExecutedHasNonZeroVoteStart(env e, uint256 proposalId)
    state(e, proposalId) == EXECUTED() => voteStartPerProposal[proposalId] > 0
    {
        preserved with (env eP) {
            require e.block.timestamp == eP.block.timestamp;
            require ValidTimeStamp(e);
        }
    }

invariant ActiveHasNonZeroVoteStart(env e, uint256 proposalId)
    state(e, proposalId) == ACTIVE() => voteStartPerProposal[proposalId] > 0
    {
        preserved with (env eP) {
            require e.block.timestamp == eP.block.timestamp;
            require ValidTimeStamp(e);
        }
    }

rule feeIsTakenOnSubmision() {
    env e;
    calldataarg args;
    require e.msg.sender != currentContract;
    uint256 _proposalFee = proposalFee();
    address token = cashToken();

    mathint accountCashTokenBalanceBefore = tokenBalanceOf(token, e.msg.sender);
    mathint contractCashTokenBalanceBefore = tokenBalanceOf(token, currentContract);
        propose(e, args);
    mathint accountCashTokenBalanceAfter = tokenBalanceOf(token, e.msg.sender);
    mathint contractCashTokenBalanceAfter = tokenBalanceOf(token, currentContract);

    assert accountCashTokenBalanceBefore == accountCashTokenBalanceAfter + _proposalFee;
    assert contractCashTokenBalanceBefore == contractCashTokenBalanceAfter - _proposalFee;
}

// rule feesArePaidBackUponExecution() {}

// // Standard Proposals succseeded ⇔ reached majority

rule onlyOneProposalStateChangesAtOnce(uint256 ID1, uint256 ID2, method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    uint16 currentEpoch = assert_uint16(clock(e));
    requireInvariant ExecutedHasNonZeroVoteStart(e, ID1);
    requireInvariant ExecutedHasNonZeroVoteStart(e, ID2);
    requireInvariant VoteStartIsNotInTheFarFuture(e, currentEpoch);
    IGovernor.ProposalState state1_pre = state(e, ID1);
    IGovernor.ProposalState state2_pre = state(e, ID2);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState state1_post = state(e, ID1);
    IGovernor.ProposalState state2_post = state(e, ID2);

    assert (state1_pre != state1_post && state2_pre != state2_post) =>
        ID1 == ID2;
}

rule queryOfStateCannotRevert(uint256 proposalId) {
    env e;
    require e.msg.value == 0;
    clock(e); /// At expected timestamps, clock shouldn't revert.
    /// Proposal exists.
    require voteStartPerProposal[proposalId] > 0;
    state@withrevert(e, proposalId);

    assert !lastReverted;
}

/// @title It's always possible to vote for an active proposal
rule votingCannotInstantlyChangeTheState(uint256 proposalId) {
    env e;
    uint8 support;
    require state(e, proposalId) == ACTIVE();

    castVote(e, proposalId, support);

    assert state(e, proposalId) == ACTIVE();
}

/// @title It's always possible to vote for an active proposal if:
/// The proposal is active
/// The voter hasn't voted yet for that proposal
/// The support type is either 'Yes' or 'No'.
rule canAlwaysVoteInVotingEpoch(uint256 proposalId) {
    env e;
    uint8 support;
    /// clock(e) shouldn't revert.
    uint16 epoch = require_uint16(clock(e));
    /// Non-payable function
    require e.msg.value == 0;
    /// Proposal is active
    require state(e, proposalId) == ACTIVE();
    /// Has not voted yet.
    require !hasVoted(proposalId, e.msg.sender);
    /// support type is valid
    require support == 0 || support == 1;
    /// No overflow
    require numberOfProposalsAt(epoch) < max_uint256;
    require numberOfProposalsVotedOnAt(e.msg.sender, epoch) < max_uint256;

    castVote@withrevert(e, proposalId, support);
    assert !lastReverted;
}

/// @title An actor without voting power cannot change any proposal vote count.
rule cannotVoteWithoutVotingPower(uint256 proposalId, address voter, bool withSig) {
    env e;
    require ValidTimeStamp(e);
    uint16 currentEpoch = assert_uint16(clock(e));
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    requireInvariant VoteStartIsNotInTheFarFuture(e, currentEpoch);
    /// If voter has no voting power...
    require getVotes(e, voter, require_uint16(clock(e) - 1)) == 0;

    uint256 yeas_before = getProposalYea(e, proposalId);
    uint256 nays_before = getProposalNay(e, proposalId);
    uint8 support;
        if(withSig) {
            bytes signature;
            castVoteBySig(e, voter, proposalId, support, signature);
        }
        else {
            require voter == e.msg.sender;
            castVote(e, proposalId, support);
        }
    uint256 yeas_after = getProposalYea(e, proposalId);
    uint256 nays_after = getProposalNay(e, proposalId);

    /// ...then the vote count cannot change.
    assert yeas_before == yeas_after && nays_before == nays_after;
}

rule proposalSucceedsOnlyWhenMajorityReached(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    uint16 currentEpoch = assert_uint16(clock(e));
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    requireInvariant VoteStartIsNotInTheFarFuture(e, currentEpoch);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    uint256 yeas = getProposalYea(e, proposalId);
    uint256 nays = getProposalNay(e, proposalId);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA != SUCCEEDED() && stateB == SUCCEEDED() => yeas > nays;
    assert stateA != DEFEATED() && stateB == DEFEATED() => yeas <= nays;
}

/// @title The 'executed' state is a terminal state of any proposal.
rule executedIsTerminal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == EXECUTED() => stateB == EXECUTED();
}

/// @title The 'canceled' state is a terminal state of any proposal.
rule canceledIsTerminal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == CANCELED() => stateB == CANCELED();
}

/// @title The 'defeated' state is a terminal state of any proposal.
rule defeatedIsTerminal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e; require ValidTimeStamp(e);
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == DEFEATED() => stateB == DEFEATED();
}

/// @title The 'expired' state is a terminal state of any proposal.
rule expiredIsTerminal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e; require ValidTimeStamp(e);
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == EXPIRED() => stateB == EXPIRED();
}

/// @title The 'succeeded' state can turn only to succeeded or executed.
rule succeededIsAlmostTerminal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    requireInvariant ActiveHasNonZeroVoteStart(e, proposalId);
    requireInvariant VoteStartIsNotInTheFarFuture(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == SUCCEEDED() => (stateB == SUCCEEDED() || stateB == EXECUTED());
    assert (stateA == SUCCEEDED() && stateB == EXECUTED()) => isExecuteMethod(f);
}

/// @title The pending state is a primal state. 
rule pendingIsPrimal(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    requireInvariant ActiveHasNonZeroVoteStart(e, proposalId);
    requireInvariant VoteStartIsNotInTheFarFuture(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA != PENDING() => stateB != PENDING();
}

rule pendingCanBecomeActiveOnly(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    require ValidTimeStamp(e);
    requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
    requireInvariant ActiveHasNonZeroVoteStart(e, proposalId);
    requireInvariant VoteStartIsNotInTheFarFuture(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg args;
        f(e, args);
    IGovernor.ProposalState stateB = state(e, proposalId);

    assert stateA == PENDING() => (stateB == PENDING() || stateB == ACTIVE());
}

rule castVotesIsAssociative() {
    env e;
    uint256 proposalId1; uint256 proposalId2;
    uint8 support1; uint8 support2;

    storage initState = lastStorage;

    castVote(e, proposalId1, support1) at initState;
    castVote(e, proposalId2, support2);

    storage stateA = lastStorage;

    castVotes(e, [proposalId1, proposalId2], [support1, support2]) at initState;

    storage stateB = lastStorage;

    assert stateA[currentContract] == stateB[currentContract];
}

invariant VotedIfProposalExists(address account, uint256 proposalId)
    hasVoted(proposalId, account) => voteStartPerProposal[proposalId] > 0
    {
        preserved with (env e) {
            require ValidTimeStamp(e);
            requireInvariant ExecutedHasNonZeroVoteStart(e, proposalId);
            requireInvariant ActiveHasNonZeroVoteStart(e, proposalId);
        }
    }

rule votedCannotBecomeUnvoted(address account, uint256 proposalId, method f) filtered{f -> !f.isView} {
    bool hasVotedBefore = hasVoted(proposalId, account);
        env e;
        calldataarg args;
        f(e,args);
    bool hasVotedAfter = hasVoted(proposalId, account);

    assert hasVotedBefore => hasVotedAfter;
}

rule votingCannotFrontRunEachOther(uint256 proposalId1, uint256 proposalId2) {
    env e1; require ValidTimeStamp(e1);
    env e2; require ValidTimeStamp(e2);
    requireInvariant ExecutedHasNonZeroVoteStart(e1, proposalId1);
    require e1.msg.sender != e2.msg.sender;
    /// Causality
    require e1.block.timestamp >= e2.block.timestamp;
    uint8 support1;
    uint8 support2;

    storage initState = lastStorage;
    castVote(e1, proposalId1, support1) at initState;

    castVote(e2, proposalId2, support2) at initState;
    castVote@withrevert(e1, proposalId1, support1);

    assert !lastReverted;
}

rule cannotMarkZeroAddressAsParticipant(method f) filtered{f -> !f.isView} {
    env e;
    require e.msg.sender !=0;
    bool participated_before = _participatedAt[0][e.block.timestamp];
        calldataarg args;
        f(e, args);
    bool participated_after = _participatedAt[0][e.block.timestamp];

    assert !participated_before => !participated_after;
}

rule cannotChangeVotesBeforeExecution(uint256 proposalId, method f) filtered{f -> !f.isView} {
    env e;
    uint256 yeas_before = getProposalYea(e, proposalId);
    uint256 nays_before = getProposalNay(e, proposalId);
        calldataarg args;
        f(e, args);
    uint256 yeas_after = getProposalYea(e, proposalId);
    uint256 nays_after = getProposalNay(e, proposalId);
    IGovernor.ProposalState stateA = state(e, proposalId);
        calldataarg argsExecute;
        execute(e, argsExecute);
    IGovernor.ProposalState stateB = state(e, proposalId);

    /// If the proposal has been executed, then no operation beforehand could have changed the votes.
    assert (stateA != EXECUTED() && stateB == EXECUTED())=>
        yeas_before == yeas_after && nays_before == nays_after;
    //satisfy (stateA != EXECUTED() && stateB == EXECUTED()); - satisfiable.
}
