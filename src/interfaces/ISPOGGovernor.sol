// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IGovernorVotesQuorumFraction} from "src/interfaces/IGovernorVotesQuorumFraction.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

interface ISPOGGovernor is IGovernorVotesQuorumFraction {
    // Errors
    error CallerIsNotSPOG(address caller);
    error SPOGAddressAlreadySet(address spog);
    error AlreadyVoted(uint256 proposalId, address account);
    error ArrayLengthsMismatch();
    error EpochInThePast(uint256 epoch, uint256 currentEpoch);

    // Events
    event VotingPeriodUpdated(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    struct ProposalVote {
        uint256 noVotes;
        uint256 yesVotes;
        mapping(address => bool) hasVoted;
    }

    /// @dev Supported vote types.
    enum VoteType {
        No,
        Yes
    }

    // public variables
    function spogAddress() external view returns (address);

    function votingToken() external view returns (ISPOGVotes);

    // public mappings
    function emergencyProposals(uint256 proposalId) external view returns (bool);

    function epochProposalsCount(uint256 epoch) external view returns (uint256);

    function accountEpochNumProposalsVotedOn(address account, uint256 epoch) external view returns (uint256);

    function epochSumOfVoteWeight(uint256 epoch) external view returns (uint256);

    // public functions

    function currentEpoch() external view returns (uint256);

    function startOfEpoch(uint256 epoch) external view returns (uint256);

    function startOfNextEpoch() external view returns (uint256);

    function initSPOGAddress(address) external;

    function proposalVotes(uint256 proposalId) external view returns (uint256 noVotes, uint256 yesVotes);

    function updateVotingTime(uint256 newVotingTime) external;

    function turnOnEmergencyVoting() external;

    function turnOffEmergencyVoting() external;

    function registerEmergencyProposal(uint256 proposalId) external;
}
