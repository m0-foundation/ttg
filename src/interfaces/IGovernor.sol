// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC6372 } from "./IERC6372.sol";

interface IGovernor is IERC6372 {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    event ProposalExecuted(uint256 proposalId);

    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 weight);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256 proposalId);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function COUNTING_MODE() external view returns (string memory countingMode);

    function getVotes(address account, uint256 timepoint) external view returns (uint256 weight);

    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256 proposalId);

    // NOTE: Does not seem to be needed by Tally, but is implemented in OpenZeppelin's Governor contract.
    function hasVoted(uint256 proposalId, address account) external view returns (bool hasVoted);

    function proposalDeadline(uint256 proposalId) external view returns (uint256 deadline);

    function proposalProposer(uint256 proposalId) external view returns (address proposer);

    function proposalSnapshot(uint256 proposalId) external view returns (uint256 snapshot);

    function quorum(uint256 timepoint) external view returns (uint256 quorum);

    // NOTE: Optionally, Tally also supports the quorumNumerator() and quorumDenominator() functions.
    //       Governors with quorums that are a function of token supply should implement these functions.
    //       If the Governor is missing either quorumNumerator() or quorumDenominator(),
    //       Tally falls back to the quorum() function and assumes that the quorum is fixed.
    // function quorumNumerator() external returns (uint256 quorumNumerator_);
    // function quorumDenominator() external returns (uint256 quorumDenominator_);

    function state(uint256 proposalId) external view returns (ProposalState state);

    function votingDelay() external view returns (uint256 votingDelay);

    function votingPeriod() external view returns (uint256 votingPeriod);
}
