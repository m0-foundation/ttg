// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

abstract contract ISPOGGovernor is IGovernor {
    // Errors
    error CallerIsNotSPOG(address caller);
    error SPOGAddressAlreadySet(address spog);
    error AlreadyVoted(uint256 proposalId, address account);
    error ArrayLengthsMistmatch(uint256 propLength, uint256 supLength);

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

    // public variables
    function spogAddress() external view virtual returns (address);

    function votingToken() external view virtual returns (ISPOGVotes);

    // public mappings
    function emergencyProposals(uint256 proposalId) external view virtual returns (bool);

    function epochStartBlockNumber(uint256 epoch) external view virtual returns (uint256);

    function epochProposalsCount(uint256 epoch) external view virtual returns (uint256);

    function accountEpochNumProposalsVotedOn(address account, uint256 epoch) external view virtual returns (uint256);

    function votingTokensMinted(uint256 epoch) external view virtual returns (bool);

    function epochSumOfVoteWeight(uint256 epoch) external view virtual returns (uint256);

    function accountEpochVoteWeight(address account, uint256 epoch) external view virtual returns (uint256);

    // public functions

    function currentVotingPeriodEpoch() external view virtual returns (uint256);

    function startOfNextVotingPeriod() public view virtual returns (uint256);

    function initSPOGAddress(address) external virtual;

    function proposalVotes(uint256 proposalId) external view virtual returns (uint256 noVotes, uint256 yesVotes);

    function updateVotingTime(uint256 newVotingTime) external virtual;

    function inflateTokenSupply() external virtual;

    function turnOnEmergencyVoting() external virtual;

    function turnOffEmergencyVoting() external virtual;

    function registerEmergencyProposal(uint256 proposalId) external virtual;

    function castVotes(uint256[] calldata proposalIds, uint8[] calldata support)
        public
        virtual
        returns (uint256[] memory);

    function updateQuorumNumerator(uint256 newQuorumNumerator) external virtual;
}
