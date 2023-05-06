// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IGovernorVotesQuorumFraction} from "../interfaces/IGovernorVotesQuorumFraction.sol";
import {ISPOGVotes} from "../interfaces/tokens/ISPOGVotes.sol";

abstract contract ISPOGGovernor is IGovernor, IGovernorVotesQuorumFraction {
    // Errors
    error CallerIsNotSPOG(address caller);
    error SPOGAddressAlreadySet(address spog);
    error AlreadyVoted(uint256 proposalId, address account);
    error ArrayLengthsMistmatch(uint256 propLength, uint256 supLength);
    error EpochInThePast(uint256 epoch, uint256 currentEpoch);

    // Events
    event VotingPeriodUpdated(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event VotingTokenInflation(uint256 indexed epoch, uint256 amount);
    event VotingTokenInflationWithdrawn(address indexed voter, uint256 amount);
    event EpochVotingTokenSupplySet(uint256 indexed epoch, uint256 amount);

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
    function spogAddress() external view virtual returns (address);

    function votingToken() external view virtual returns (ISPOGVotes);

    // public mappings
    function emergencyProposals(uint256 proposalId) external view virtual returns (bool);

    function epochProposalsCount(uint256 epoch) external view virtual returns (uint256);

    function accountEpochNumProposalsVotedOn(address account, uint256 epoch) external view virtual returns (uint256);

    function epochSumOfVoteWeight(uint256 epoch) external view virtual returns (uint256);

    // public functions

    function currentEpoch() external view virtual returns (uint256);

    function startOfEpoch(uint256 epoch) external view virtual returns (uint256);

    function startOfNextEpoch() external view virtual returns (uint256);

    function initSPOGAddress(address) external virtual;

    function proposalVotes(uint256 proposalId) external view virtual returns (uint256 noVotes, uint256 yesVotes);

    function updateVotingTime(uint256 newVotingTime) external virtual;

    function turnOnEmergencyVoting() external virtual;

    function turnOffEmergencyVoting() external virtual;

    function registerEmergencyProposal(uint256 proposalId) external virtual;

    function castVotes(uint256[] calldata proposalIds, uint8[] calldata support)
        external
        virtual
        returns (uint256[] memory);
}
