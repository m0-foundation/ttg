// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";

import { IGovernor } from "./interfaces/IGovernor.sol";
import { IThresholdGovernor } from "./interfaces/IThresholdGovernor.sol";

import { BatchGovernor } from "./BatchGovernor.sol";

/**
 * @title  Extension for BatchGovernor with a threshold ratio used to determine quorum and yes-threshold requirements.
 * @author M^0 Labs
 */
abstract contract ThresholdGovernor is IThresholdGovernor, BatchGovernor {
    /* ============ Variables ============ */

    /// @dev The minimum allowed threshold ratio.
    uint16 internal constant _MIN_THRESHOLD_RATIO = 271;

    /// @inheritdoc IThresholdGovernor
    uint16 public thresholdRatio;

    /* ============ Constructor ============ */

    /**
     * @notice Construct a new ThresholdGovernor contract.
     * @param  name_           The name of the contract. Used to compute EIP712 domain separator.
     * @param  voteToken_      The address of the token used to vote.
     * @param  thresholdRatio_ The ratio of yes votes votes required for a proposal to succeed.
     */
    constructor(string memory name_, address voteToken_, uint16 thresholdRatio_) BatchGovernor(name_, voteToken_) {
        _setThresholdRatio(thresholdRatio_);
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IGovernor
    function execute(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external payable returns (uint256 proposalId_) {
        uint16 latestPossibleVoteStart_ = _clock();

        // Proposals have voteStart=N and voteEnd=N+1, and can be executed only during epochs N and N+1.
        proposalId_ = _tryExecute(callDatas_[0], latestPossibleVoteStart_, latestPossibleVoteStart_ - 1);
    }

    /// @inheritdoc IGovernor
    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external returns (uint256 proposalId_) {
        (proposalId_, ) = _propose(targets_, values_, callDatas_, description_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IThresholdGovernor
    function getProposal(
        uint256 proposalId_
    )
        external
        view
        returns (
            uint48 voteStart_,
            uint48 voteEnd_,
            ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_,
            uint16 thresholdRatio_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        voteStart_ = proposal_.voteStart;
        voteEnd_ = _getVoteEnd(proposal_.voteStart);
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
        thresholdRatio_ = proposal_.thresholdRatio;
    }

    /// @inheritdoc IGovernor
    function quorum() external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(_clock() - 1)) / ONE;
    }

    /// @inheritdoc IGovernor
    function quorum(uint256 timepoint_) external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(UIntMath.safe16(timepoint_) - 1)) / ONE;
    }

    /// @inheritdoc IGovernor
    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint16 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        uint256 totalSupply_ = _getTotalSupply(voteStart_ - 1);
        bool isVotingOpen_ = _clock() <= _getVoteEnd(voteStart_);

        // If the total supply of Vote Tokens is 0 and the vote has not ended yet, the proposal is active.
        // The proposal will expire once the voting period closes.
        if (totalSupply_ == 0) return isVotingOpen_ ? ProposalState.Active : ProposalState.Expired;

        uint16 thresholdRatio_ = proposal_.thresholdRatio;

        // If proposal is currently succeeding, it has either succeeded or expired.
        if (proposal_.yesWeight * ONE >= thresholdRatio_ * totalSupply_) {
            return isVotingOpen_ ? ProposalState.Succeeded : ProposalState.Expired;
        }

        // If proposal can succeed while voting is open, it is active.
        if (((totalSupply_ - proposal_.noWeight) * ONE >= thresholdRatio_ * totalSupply_) && isVotingOpen_) {
            return ProposalState.Active;
        }

        return ProposalState.Defeated;
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Creates a new proposal with the given parameters.
     * @param proposalId_ The unique identifier of the proposal.
     * @param voteStart_  The epoch at which the proposal will start collecting votes.
     */
    function _createProposal(uint256 proposalId_, uint16 voteStart_) internal override {
        _proposals[proposalId_] = Proposal({
            voteStart: voteStart_,
            executed: false,
            proposer: msg.sender,
            thresholdRatio: thresholdRatio,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
    }

    /**
     * @dev   Set the threshold ratio to be applied to determine the threshold/quorum for a proposal.
     * @param newThresholdRatio_ The new threshold ratio.
     */
    function _setThresholdRatio(uint16 newThresholdRatio_) internal {
        if (newThresholdRatio_ > ONE || newThresholdRatio_ < _MIN_THRESHOLD_RATIO)
            revert InvalidThresholdRatio(newThresholdRatio_, _MIN_THRESHOLD_RATIO, ONE);

        emit ThresholdRatioSet(thresholdRatio = newThresholdRatio_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Returns the number of clock values that must elapse before voting begins for a newly created proposal.
     * @return The voting delay.
     */
    function _votingDelay() internal pure override returns (uint16) {
        return 0;
    }

    /**
     * @dev    Returns the number of clock values between the vote start and vote end.
     * @return The voting period.
     */
    function _votingPeriod() internal pure override returns (uint16) {
        return 1;
    }
}
