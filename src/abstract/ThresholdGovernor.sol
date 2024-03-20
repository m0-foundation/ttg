// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IGovernor } from "./interfaces/IGovernor.sol";
import { IThresholdGovernor } from "./interfaces/IThresholdGovernor.sol";

import { BatchGovernor } from "./BatchGovernor.sol";

/**
 * @title  Extension for BatchGovernor with a quorum ratio used to determine quorum and yes-threshold requirements.
 * @author M^0 Labs
 */
abstract contract ThresholdGovernor is IThresholdGovernor, BatchGovernor {
    /* ============ Variables ============ */

    /// @dev The minimum allowed quorum numerator.
    uint16 internal constant _MIN_QUORUM_NUMERATOR = 271;

    /// @dev The denominator used to compute quorum (100% in basis points).
    uint16 internal constant _QUORUM_DENOMINATOR = 10_000;

    /// @dev The quorum numerator used to compute quorum.
    uint16 internal _quorumNumerator;

    /* ============ Constructor ============ */

    /**
     * @notice Construct a new ThresholdGovernor contract.
     * @param  name_            The name of the contract. Used to compute EIP712 domain separator.
     * @param  voteToken_       The address of the token used to vote.
     * @param  quorumNumerator_ The numerator used to compute the yes quorum required for a proposal to succeed.
     */
    constructor(string memory name_, address voteToken_, uint256 quorumNumerator_) BatchGovernor(name_, voteToken_) {
        _setQuorumNumerator(quorumNumerator_);
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

    /// @inheritdoc IGovernor
    function COUNTING_MODE() external pure returns (string memory) {
        return "support=against,for&quorum=for&success=quorum";
    }

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
            uint256 quorum_,
            uint16 quorumNumerator_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        voteStart_ = proposal_.voteStart;
        voteEnd_ = _getVoteEnd(proposal_.voteStart);
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
        quorum_ = _getQuorum(proposal_.voteStart, proposal_.quorumNumerator);
        quorumNumerator_ = proposal_.quorumNumerator;
    }

    /// @inheritdoc IThresholdGovernor
    function proposalQuorum(uint256 proposalId) external view returns (uint256) {
        Proposal storage proposal_ = _proposals[proposalId];

        return _getQuorum(proposal_.voteStart, proposal_.quorumNumerator);
    }

    /// @inheritdoc IGovernor
    function quorum() external view returns (uint256) {
        // NOTE: This only provides the quorum required for a proposal created at this moment.
        return _getQuorum(_clock(), _quorumNumerator);
    }

    /// @inheritdoc IThresholdGovernor
    function quorumNumerator() external view returns (uint256) {
        return _quorumNumerator;
    }

    /// @inheritdoc IThresholdGovernor
    function quorumDenominator() external pure returns (uint256) {
        return _QUORUM_DENOMINATOR;
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

        uint16 quorumNumerator_ = proposal_.quorumNumerator;

        // If proposal is currently succeeding, it has either succeeded or expired.
        if (proposal_.yesWeight * _QUORUM_DENOMINATOR >= quorumNumerator_ * totalSupply_) {
            return isVotingOpen_ ? ProposalState.Succeeded : ProposalState.Expired;
        }

        // If proposal can succeed while voting is open, it is active.
        if (
            ((totalSupply_ - proposal_.noWeight) * _QUORUM_DENOMINATOR >= quorumNumerator_ * totalSupply_) &&
            isVotingOpen_
        ) {
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
            quorumNumerator: _quorumNumerator,
            noWeight: 0,
            yesWeight: 0
        });
    }

    /**
     * @dev   Set the quorum numerator to be used to compute the threshold/quorum for a proposal.
     * @param newQuorumNumerator_ The new quorum numerator.
     */
    function _setQuorumNumerator(uint256 newQuorumNumerator_) internal {
        if (newQuorumNumerator_ > _QUORUM_DENOMINATOR || newQuorumNumerator_ < _MIN_QUORUM_NUMERATOR)
            revert InvalidQuorumNumerator(newQuorumNumerator_, _MIN_QUORUM_NUMERATOR, _QUORUM_DENOMINATOR);

        emit QuorumNumeratorUpdated(_quorumNumerator, newQuorumNumerator_);

        _quorumNumerator = uint16(newQuorumNumerator_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Returns the quorum given a snapshot and quorum numerator.
     * @param  voteStart_       The epoch at which the proposal will start collecting votes.
     * @param  quorumNumerator_ The quorum numerator.
     * @return quorum_          The quorum of yes voted needed for a successful proposal.
     */
    function _getQuorum(uint16 voteStart_, uint16 quorumNumerator_) internal view returns (uint256 quorum_) {
        return (quorumNumerator_ * _getTotalSupply(voteStart_ - 1)) / _QUORUM_DENOMINATOR;
    }

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
