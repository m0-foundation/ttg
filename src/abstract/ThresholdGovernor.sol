// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IGovernor } from "./interfaces/IGovernor.sol";
import { IThresholdGovernor } from "./interfaces/IThresholdGovernor.sol";

import { BatchGovernor } from "./BatchGovernor.sol";

// TODO: Determine `quorumNumerator`/`quorumDenominator`/`QuorumNumeratorUpdated` stuff, and how it applies to tokens
//       with a growing total supply.
//       See: https://docs.tally.xyz/user-guides/tally-contract-compatibility/openzeppelin-governor
//       See: https://docs.openzeppelin.com/contracts/4.x/api/governance#GovernorVotesQuorumFraction-quorumDenominator--
//       See: https://portal.thirdweb.com/contracts/VoteERC20

/// @title Extension for BatchGovernor with a threshold ratio used to determine quorum and yes-threshold requirements.
abstract contract ThresholdGovernor is IThresholdGovernor, BatchGovernor {
    /// @notice The minimum allowed threshold ratio.
    uint256 internal constant _MIN_THRESHOLD_RATIO = 271;

    /// @inheritdoc IThresholdGovernor
    uint16 public thresholdRatio;

    /**
     * @notice Construct a new ThresholdGovernor contract.
     * @param  name_           The name of the contract. Used to compute EIP712 domain separator.
     * @param  voteToken_      The address of the token used to vote.
     * @param  thresholdRatio_ The ratio of yes votes votes required for a proposal to succeed.
     */
    constructor(string memory name_, address voteToken_, uint16 thresholdRatio_) BatchGovernor(name_, voteToken_) {
        _setThresholdRatio(thresholdRatio_);
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IGovernor
    function execute(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external payable returns (uint256 proposalId_) {
        uint256 currentEpoch_ = clock();

        if (currentEpoch_ == 0) revert InvalidEpoch();

        // Proposals have voteStart=N and voteEnd=N+1, and can be executed only during epochs N and N+1.
        uint256 latestPossibleVoteStart_ = currentEpoch_;
        uint256 earliestPossibleVoteStart_ = latestPossibleVoteStart_ > 0 ? latestPossibleVoteStart_ - 1 : 0;

        proposalId_ = _tryExecute(callDatas_[0], latestPossibleVoteStart_, earliestPossibleVoteStart_);
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

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

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
        voteEnd_ = _getVoteEnd(voteStart_);
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
        thresholdRatio_ = proposal_.thresholdRatio;
    }

    /// @inheritdoc IGovernor
    function quorum() external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(clock() - 1)) / ONE;
    }

    /// @inheritdoc IGovernor
    function quorum(uint256 timepoint_) external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(timepoint_ - 1)) / ONE;
    }

    /// @inheritdoc IGovernor
    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        uint256 currentEpoch_ = clock();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        uint256 totalSupply_ = _getTotalSupply(voteStart_ - 1);
        uint256 thresholdRatio_ = proposal_.thresholdRatio;

        bool isVotingOpen_ = currentEpoch_ <= _getVoteEnd(voteStart_);

        // If the total supply of Vote Tokens is 0 and the vote has not ended yet, the proposal is active.
        // The proposal will expire once the voting period closes.
        if (totalSupply_ == 0) return isVotingOpen_ ? ProposalState.Active : ProposalState.Expired;

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

    /// @inheritdoc IGovernor
    function votingDelay() public pure override(BatchGovernor, IGovernor) returns (uint256 votingDelay_) {
        return 0;
    }

    /// @inheritdoc IGovernor
    function votingPeriod() public pure override(BatchGovernor, IGovernor) returns (uint256 votingPeriod_) {
        return 1;
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _createProposal(uint256 proposalId_, uint256 voteStart_) internal override {
        _proposals[proposalId_] = Proposal({
            voteStart: uint48(voteStart_),
            executed: false,
            proposer: msg.sender,
            thresholdRatio: thresholdRatio,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
    }

    function _setThresholdRatio(uint16 newThresholdRatio_) internal {
        if (newThresholdRatio_ > ONE || newThresholdRatio_ < _MIN_THRESHOLD_RATIO)
            revert InvalidThresholdRatio(newThresholdRatio_, _MIN_THRESHOLD_RATIO, ONE);

        emit ThresholdRatioSet(thresholdRatio = newThresholdRatio_);
    }
}
