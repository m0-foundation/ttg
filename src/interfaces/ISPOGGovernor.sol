// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "src/interfaces/tokens/ISPOGVotes.sol";
import "src/interfaces/ISPOG.sol";

abstract contract ISPOGGovernor is Governor, IDualGovernor {}

interface IDualGovernor {
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
    event Proposal(uint256 indexed epoch, uint256 indexed proposalId, ProposalType indexed proposalType);

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
    function isGovernedMethod(bytes4 func) external pure returns (bool);

    function proposalVotes(uint256 proposalId) external view returns (uint256, uint256);
    function proposalValueVotes(uint256 proposalId) external view returns (uint256, uint256);

    function voteQuorumNumerator() external view returns (uint256);
    function valueQuorumNumerator() external view returns (uint256);
    function quorumDenominator() external view returns (uint256);
    function voteQuorum(uint256 timepoint) external view returns (uint256);
    function voteQuorumNumerator(uint256 timepoint) external view returns (uint256);
    function valueQuorum(uint256 timepoint) external view returns (uint256);
    function valueQuorumNumerator(uint256 timepoint) external view returns (uint256);
    function updateVoteQuorumNumerator(uint256 newVoteQuorumNumerator) external;
    function updateValueQuorumNumerator(uint256 newValueQuorumNumerator) external;

    function currentEpoch() external view returns (uint256);
    function startOf(uint256 epoch) external view returns (uint256);
    function epochTotalVotesWeight(uint256 epoch) external view returns (uint256);
    function isActiveParticipant(uint256 epoch, address account) external view returns (bool);
}
