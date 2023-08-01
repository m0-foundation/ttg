// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IDualGovernorQuorum } from "./IDualGovernorQuorum.sol";
import { IControlledByComptroller } from "../comptroller/IControlledByComptroller.sol";

// NOTE: Openzeppelin erroneously declared `IGovernor` as abstract contract, so this needs to follow suit.
abstract contract IDualGovernor is IControlledByComptroller, IDualGovernorQuorum {
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
    error AlreadyVoted();
    error ProposalIsNotInActiveState();

    // Events
    event Proposal(
        uint256 indexed epoch,
        uint256 indexed proposalId,
        ProposalType indexed proposalType,
        address target,
        bytes data,
        string description
    );
    event MandatoryVotingFinished(
        uint256 indexed epoch,
        address indexed account,
        uint256 indexed blockNumber,
        uint256 totalVotedWeight
    );
    event InflationAndRewardsAccrued(
        uint256 indexed epoch,
        address indexed account,
        uint256 inflation,
        uint256 rewards
    );

    // Utility functions
    function isGovernedMethod(bytes4 func) external pure virtual returns (bool);

    function emergencyProposals(uint256 proposalId) external view virtual returns (bool);

    // Vote and value votes results
    function proposalVotes(uint256 proposalId) external view virtual returns (uint256, uint256);

    function proposalValueVotes(uint256 proposalId) external view virtual returns (uint256, uint256);

    // Epochs logic
    function currentEpoch() external view virtual returns (uint256);

    function startOf(uint256 epoch) external pure virtual returns (uint256);

    function epochTotalVotesWeight(uint256 epoch) external view virtual returns (uint256);

    function hasFinishedVoting(uint256 epoch, address account) external view virtual returns (bool);

    function finishedVotingAt(uint256 epoch, address account) external view virtual returns (uint256);

    // Batch voting
    function castVotes(uint256[] calldata proposalIds, uint8[] calldata votes) external virtual;
}
