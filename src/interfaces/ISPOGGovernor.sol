// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "src/interfaces/tokens/ISPOGVotes.sol";
import "src/interfaces/ISPOG.sol";

interface ISPOGGovernor {
    // Errors
    error TooManyTargets();
    error InvalidTarget();
    error InvalidValue();
    error InvalidMethod();
    error ListAdminIsNotSPOG();
    error AlreadyInitialized();
    error AlreadyVoted(uint256 proposalId, address account);
    error EpochInThePast(uint256 epoch, uint256 currentEpoch);
    error ZeroSPOGAddress();

    // Events
    event NewProposal(uint256 indexed epoch, uint256 indexed proposalId, ProposalType indexed proposalType);

    struct EpochBasic {
        uint256 numProposals;
        uint256 totalVotesWeight;
        mapping(address => uint256) numVotedOn;
    }

    struct ProposalVote {
        uint256 voteNoVotes;
        uint256 voteYesVotes;
        uint256 valueNoVotes;
        uint256 valueYesVotes;
        mapping(address => bool) hasVoted;
    }

    enum ProposalType {
        Vote,
        Double,
        Value
    }

    /// @dev Supported vote types.
    enum VoteType {
        No,
        Yes
    }

    function spog() external view returns (ISPOG);
    function vote() external view returns (ISPOGVotes);
    function value() external view returns (ISPOGVotes);

    function initSPOGAddress(address) external;
    function emergencyProposals(uint256 proposalId) external view returns (bool);

    function epochTotalVotesWeight(uint256 epoch) external view returns (uint256);
    function isActiveParticipant(uint256 epoch, address account) external view returns (bool);
    function proposalVotes(uint256 proposalId) external view returns (uint256, uint256);
    function proposalValueVotes(uint256 proposalId) external view returns (uint256, uint256);

    function currentEpoch() external view returns (uint256);
    function startOf(uint256 epoch) external view returns (uint256);
}
