// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";

import "src/interfaces/tokens/ISPOGVotes.sol";
import "src/interfaces/ISPOG.sol";

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
    error AlreadyInitialized();
    error AlreadyVoted();
    error ZeroSPOGAddress();
    error ZeroVotingPeriod();
    error ZeroVoteAddress();
    error ZeroValueAddress();
    error ZeroVoteQuorumNumerator();
    error ZeroValueQuorumNumerator();
    error InvalidVoteQuorumNumerator();
    error InvalidValueQuorumNumerator();

    // Events
    event Proposal(uint256 indexed epoch, uint256 indexed proposalId, ProposalType indexed proposalType);
    event ValueQuorumNumeratorUpdated(uint256 oldValueQuorumNumerator, uint256 newValueQuorumNumerator);
    event VoteQuorumNumeratorUpdated(uint256 oldVoteQuorumNumerator, uint256 newVoteQuorumNumerator);

    // Accessors for vote, value tokens and spog contract
    function spog() external view returns (ISPOG);
    function vote() external view returns (ISPOGVotes);
    function value() external view returns (ISPOGVotes);

    // Utility functions
    function initSPOGAddress(address) external;
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
    function isActiveParticipant(uint256 epoch, address account) external view returns (bool);
}

abstract contract ISPOGGovernor is Governor, IDualGovernor {}
