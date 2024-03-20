// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IBatchGovernor } from "./IBatchGovernor.sol";

/**
 * @title  Extension for BatchGovernor with a quorum ratio used to determine quorum and yes-threshold requirements.
 * @author M^0 Labs
 */
interface IThresholdGovernor is IBatchGovernor {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the quorum numerator is set.
     * @param  oldQuorumNumerator The old quorum numerator.
     * @param  newQuorumNumerator The new quorum numerator.
     */
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when trying to set the quorum numerator above 100% or below 2.71%.
     * @param  quorumNumerator    The quorum numerator being set.
     * @param  minQuorumNumerator The minimum allowed quorum numerator.
     * @param  maxQuorumNumerator The maximum allowed quorum numerator.
     */
    error InvalidQuorumNumerator(uint256 quorumNumerator, uint256 minQuorumNumerator, uint256 maxQuorumNumerator);

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns all data of a proposal with identifier `proposalId`.
     * @param  proposalId      The unique identifier for the proposal.
     * @return voteStart       The first clock value when voting on the proposal is allowed.
     * @return voteEnd         The last clock value when voting on the proposal is allowed.
     * @return state           The state of the proposal.
     * @return noVotes         The amount of votes cast against the proposal.
     * @return yesVotes        The amount of votes cast for the proposal.
     * @return proposer        The address of the account that created the proposal.
     * @return quorum          The threshold/quorum of yes votes required for the proposal to succeed.
     * @return quorumNumerator The threshold/quorum numerator used to calculate the quorum.
     */
    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint48 voteStart,
            uint48 voteEnd,
            ProposalState state,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer,
            uint256 quorum,
            uint16 quorumNumerator
        );

    /**
     * @notice Returns the quorum/threshold of yes votes needed for a specific proposal to succeed.
     * @param  proposalId The unique identifier for the proposal.
     * @return The quorum/threshold of yes votes needed for the proposal to succeed.
     */
    function proposalQuorum(uint256 proposalId) external view returns (uint256);

    /// @notice Returns the quorum numerator used to determine the threshold/quorum for a proposal.
    function quorumNumerator() external view returns (uint256);

    /// @notice Returns the quorum denominator used to determine the threshold/quorum for a proposal.
    function quorumDenominator() external view returns (uint256);
}
