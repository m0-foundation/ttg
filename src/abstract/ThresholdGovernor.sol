// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IGovernor } from "./interfaces/IGovernor.sol";
import { IThresholdGovernor } from "./interfaces/IThresholdGovernor.sol";

import { BatchGovernor } from "./BatchGovernor.sol";

// TODO: Determine `quorumNumerator`/`quorumDenominator`/`QuorumNumeratorUpdated` stuff, and how it applies to tokens
//       with a growing total supply.
//       See: https://docs.tally.xyz/user-guides/tally-contract-compatibility/openzeppelin-governor
//       See: https://docs.openzeppelin.com/contracts/4.x/api/governance#GovernorVotesQuorumFraction-quorumDenominator--
//       See: https://portal.thirdweb.com/contracts/VoteERC20

abstract contract ThresholdGovernor is IThresholdGovernor, BatchGovernor {
    uint16 public thresholdRatio;

    constructor(string memory name_, address voteToken_, uint16 thresholdRatio_) BatchGovernor(name_, voteToken_) {
        _setThresholdRatio(thresholdRatio_);
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function execute(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external payable returns (uint256 proposalId_) {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ == 0) revert InvalidEpoch();

        // Proposals have voteStart=N and voteEnd=N+1, and can be executed only during epochs N and N+1.
        uint256 latestPossibleVoteStart_ = PureEpochs.currentEpoch();
        uint256 earliestPossibleVoteStart_ = latestPossibleVoteStart_ > 0 ? latestPossibleVoteStart_ - 1 : 0;

        proposalId_ = _tryExecute(callDatas_[0], latestPossibleVoteStart_, earliestPossibleVoteStart_);
    }

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

    function getProposal(
        uint256 proposalId_
    )
        external
        view
        returns (
            uint16 voteStart_,
            uint16 voteEnd_,
            bool executed_,
            ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_,
            uint16 thresholdRatio_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        voteStart_ = proposal_.voteStart;
        voteEnd_ = proposal_.voteEnd;
        executed_ = proposal_.executed;
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
        thresholdRatio_ = proposal_.thresholdRatio;
    }

    function proposalFee() external pure returns (uint256 proposalFee_) {
        return 0;
    }

    function quorum() external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(PureEpochs.currentEpoch() - 1)) / ONE;
    }

    function quorum(uint256 timepoint_) external view returns (uint256 quorum_) {
        // NOTE: This will only be correct for the first epoch of a proposals lifetime.
        return (thresholdRatio * _getTotalSupply(timepoint_ - 1)) / ONE;
    }

    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        uint256 totalSupply_ = _getTotalSupply(voteStart_ - 1);
        uint256 thresholdRatio_ = proposal_.thresholdRatio;

        // If proposal is currently succeeding, it has either succeeded or expired.
        if (proposal_.yesWeight * ONE >= thresholdRatio_ * totalSupply_) {
            return currentEpoch_ <= proposal_.voteEnd ? ProposalState.Succeeded : ProposalState.Expired;
        }

        bool canSucceed_ = (totalSupply_ - proposal_.noWeight) * ONE >= thresholdRatio_ * totalSupply_;

        // If proposal can succeed while voting is open, it is active.
        if (canSucceed_ && currentEpoch_ <= proposal_.voteEnd) return ProposalState.Active;

        return ProposalState.Defeated;
    }

    function votingDelay() public pure override(BatchGovernor, IGovernor) returns (uint256 votingDelay_) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256 votingPeriod_) {
        return 1;
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _createProposal(uint256 proposalId_, uint256 voteStart_) internal override returns (uint256 voteEnd_) {
        voteEnd_ = voteStart_ + 1;

        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: false,
            proposer: msg.sender,
            thresholdRatio: thresholdRatio,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
    }

    function _setThresholdRatio(uint16 newThresholdRatio_) internal {
        if (newThresholdRatio_ > ONE) revert InvalidThresholdRatio();

        emit ThresholdRatioSet(thresholdRatio = newThresholdRatio_);
    }
}
