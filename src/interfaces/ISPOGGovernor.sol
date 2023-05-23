// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

interface ISPOGGovernor {
    // Errors
    error CallerIsNotSPOG(address caller);
    error SPOGAddressAlreadySet(address spog);
    error AlreadyVoted(uint256 proposalId, address account);
    error ArrayLengthsMismatch();
    error EpochInThePast(uint256 epoch, uint256 currentEpoch);

    // Errors
    error InvalidProposal();
    error NotGovernedMethod(bytes4 funcSelector);
    error OnlyGovernor();

    // Events
    event VotingPeriodUpdated(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    struct ProposalVote {
        uint256 voteNoVotes;
        uint256 voteYesVotes;
        uint256 valueNoVotes;
        uint256 valueYesVotes;
        mapping(address => bool) hasVoted;
    }

    enum ProposalType {
        Value,
        Vote,
        Double
    }

    /// @dev Supported vote types.
    enum VoteType {
        No,
        Yes
    }

    // public variables
    function spogAddress() external view returns (address);

    // function vote() external view returns (ISPOGVotes);
    // function value() external view returns (ISPOGVotes);

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

    function proposalVoteVotes(uint256 proposalId) external view returns (uint256 noVotes, uint256 yesVotes);
    function proposalValueVotes(uint256 proposalId) external view returns (uint256 noVotes, uint256 yesVotes);

    function updateVotingTime(uint256 newVotingTime) external;
}
