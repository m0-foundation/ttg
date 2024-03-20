// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IBatchGovernor } from "./IBatchGovernor.sol";

/**
 * @title  Extension for BatchGovernor with a threshold ratio used to determine quorum and yes-threshold requirements.
 * @author M^0 Labs
 */
interface IThresholdGovernor is IBatchGovernor {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the threshold ratio is set.
     * @param  thresholdRatio The new threshold ratio.
     */
    event ThresholdRatioSet(uint16 thresholdRatio);

    /**
     * @notice Emitted when the quorum numerator is set.
     * @param  oldQuorumNumerator The old quorum numerator.
     * @param  newQuorumNumerator The new quorum numerator.
     */
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when trying to set the threshold ratio above 100% or below 2.71%.
     * @param  thresholdRatio    The threshold ratio being set.
     * @param  minThresholdRatio The minimum allowed threshold ratio.
     * @param  maxThresholdRatio The maximum allowed threshold ratio.
     */
    error InvalidThresholdRatio(uint256 thresholdRatio, uint256 minThresholdRatio, uint256 maxThresholdRatio);

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
     * @notice Returns the threshold ratio to be applied to determine the success threshold for a proposal.
     * @dev    For all intents and purposes, this is the same as `quorumNumerator`.
     */
    function thresholdRatio() external view returns (uint16);

    /**
     * @notice Returns the quorum of yes votes needed for a specific proposal to succeed.
     * @param  proposalId The unique identifier for the proposal.
     * @return The quorum of yes votes needed for the proposal to succeed.
     */
    function proposalQuorum(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Returns the quorum numerator used to determine the quorum for a proposal.
     * @dev    For all intents and purposes, this is the same as `thresholdRatio`.
     */
    function quorumNumerator() external view returns (uint256);

    /// @notice Returns the quorum denominator used to determine the quorum for a proposal.
    function quorumDenominator() external view returns (uint256);

    /// @notice Returns the value used as 100%, to be used to correctly ascertain the threshold ratio.
    function ONE() external pure returns (uint256);
}
