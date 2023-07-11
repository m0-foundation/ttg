// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernor } from "./ImportedInterfaces.sol";
import { ISPOGControlled } from "./ISPOGControlled.sol";
import { IVOTE, IVALUE } from "./ITokens.sol";

interface IDualGovernor {

    // Enums
    enum ProposalType {
        Vote,
        Double,
        Value
    }

    enum VoteType {
        No,
        Yes
    }

    // Errors
    error TooManyTargets();
    error InvalidTarget();
    error InvalidValue();
    error InvalidMethod();
    error ListAdminIsNotSPOG();
    error AlreadyVoted();
    error ZeroSPOGAddress();
    error ZeroVotingPeriod();
    error ZeroVoteAddress();
    error ZeroValueAddress();
    error ZeroVoteQuorumNumerator();
    error ZeroValueQuorumNumerator();
    error InvalidVoteQuorumNumerator();
    error InvalidValueQuorumNumerator();
    error ZeroStart();
    error VoteValueMismatch();

    // Events
    event Proposal(uint256 indexed epoch, uint256 indexed proposalId, ProposalType indexed proposalType);
    event ValueQuorumNumeratorUpdated(uint256 oldValueQuorumNumerator, uint256 newValueQuorumNumerator);
    event VoteQuorumNumeratorUpdated(uint256 oldVoteQuorumNumerator, uint256 newVoteQuorumNumerator);
    event VotingFinishedAndRewardsAccrued(
        address indexed account, uint256 indexed epoch, uint256 blockNumber, uint256 votesWeightReward
    );

    // Accessors for vote, value tokens and spog contract
    function vote() external view returns (IVOTE);
    function value() external view returns (IVALUE);

    // Utility functions
    function isGovernedMethod(bytes4 func) external pure returns (bool);
    function emergencyProposals(uint256 proposalId) external view returns (bool);

    // Vote and value votes results
    function proposalVotes(uint256 proposalId) external view returns (uint256, uint256);
    function proposalValueVotes(uint256 proposalId) external view returns (uint256, uint256);

    // Vote and value quorums
    function voteQuorumNumerator() external view returns (uint256);
    function valueQuorumNumerator() external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function voteQuorum(uint256 timepoint) external view returns (uint256);
    function voteQuorumNumerator(uint256 timepoint) external view returns (uint256);
    function valueQuorum(uint256 timepoint) external view returns (uint256);
    function valueQuorumNumerator(uint256 timepoint) external view returns (uint256);
    function updateVoteQuorumNumerator(uint256 newVoteQuorumNumerator) external;
    function updateValueQuorumNumerator(uint256 newValueQuorumNumerator) external;

    // Epochs logic
    function currentEpoch() external view returns (uint256);
    function startOf(uint256 epoch) external view returns (uint256);
    function epochTotalVotesWeight(uint256 epoch) external view returns (uint256);
    function hasFinishedVoting(uint256 epoch, address account) external view returns (bool);
    function finishedVotingAt(uint256 epoch, address account) external view returns (uint256);

    // Batch voting
    function castVotes(uint256[] calldata proposalIds, uint8[] calldata votes) external;

}

// NOTE: Openzeppelin erroneously declared `IGovernor` as abstract contract, so this needs to follow suit.
abstract contract ISPOGGovernor is IGovernor, IDualGovernor, ISPOGControlled {}
