// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC712 } from "../../lib/common/src/ERC712.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IBatchGovernor } from "./interfaces/IBatchGovernor.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

/// @title Extension for Governor with specialized strict proposal parameters, vote batching, and an epoch clock.
abstract contract BatchGovernor is IBatchGovernor, ERC712 {
    // TODO: Ensure this is correctly compacted into one slot.
    // TODO: Consider popping proposer out of this struct and into its own mapping as its mostly useless.
    struct Proposal {
        uint48 voteStart;
        bool executed;
        address proposer;
        uint16 thresholdRatio;
        uint16 quorumRatio;
        uint256 noWeight;
        uint256 yesWeight;
    }

    uint256 public constant ONE = 10_000;

    // keccak256("Ballot(uint256 proposalId,uint8 support)")
    bytes32 public constant BALLOT_TYPEHASH = 0x150214d74d59b7d1e90c73fc22ef3d991dd0a76b046543d4d80ab92d2a50328f;

    // keccak256("Ballots(uint256[] proposalIds,uint8[] support)")
    bytes32 public constant BALLOTS_TYPEHASH = 0x17b363a9cc71c97648659dc006723bbea6565fe35148add65f6887abf5158d39;

    address public immutable voteToken;

    mapping(uint256 proposalId => Proposal proposal) internal _proposals;

    mapping(uint256 proposalId => mapping(address voter => bool hasVoted)) public hasVoted;

    modifier onlySelf() {
        _revertIfNotSelf();
        _;
    }

    constructor(string memory name_, address voteToken_) ERC712(name_) {
        if ((voteToken = voteToken_) == address(0)) revert InvalidVoteTokenAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function castVote(uint256 proposalId_, uint8 support_) external returns (uint256 weight_) {
        (weight_, ) = _castVote(msg.sender, proposalId_, support_);
    }

    function castVotes(uint256[] calldata proposalIds_, uint8[] calldata supports_) external returns (uint256 weight_) {
        return _castVotes(msg.sender, proposalIds_, supports_);
    }

    function castVoteWithReason(
        uint256 proposalId_,
        uint8 support_,
        string calldata
    ) external returns (uint256 weight_) {
        (weight_, ) = _castVote(msg.sender, proposalId_, support_);
    }

    function castVoteBySig(
        uint256 proposalId_,
        uint8 support_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        (weight_, ) = _castVote(
            _getSignerAndRevertIfInvalidSignature(_getBallotDigest(proposalId_, support_), v_, r_, s_),
            proposalId_,
            support_
        );
    }

    function castVoteBySig(
        address voter_,
        uint256 proposalId_,
        uint8 support_,
        bytes memory signature_
    ) external returns (uint256 weight_) {
        _revertIfInvalidSignature(voter_, _getBallotDigest(proposalId_, support_), signature_);

        (weight_, ) = _castVote(voter_, proposalId_, support_);
    }

    function castVotesBySig(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return
            _castVotes(
                _getSignerAndRevertIfInvalidSignature(_getBallotsDigest(proposalIds_, supports_), v_, r_, s_),
                proposalIds_,
                supports_
            );
    }

    function castVotesBySig(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        bytes memory signature_
    ) external returns (uint256 weight_) {
        _revertIfInvalidSignature(voter_, _getBallotsDigest(proposalIds_, supports_), signature_);

        return _castVotes(voter_, proposalIds_, supports_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        return "mode=epoch";
    }

    function COUNTING_MODE() external pure returns (string memory countingMode_) {
        return "support=for,against&quorum=for";
    }

    function clock() public view returns (uint48 clock_) {
        return uint48(PureEpochs.currentEpoch());
    }

    function getVotes(address account_, uint256 timepoint_) public view returns (uint256 weight_) {
        return IEpochBasedVoteToken(voteToken).getPastVotes(account_, timepoint_);
    }

    function hashProposal(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external view returns (uint256 proposalId_) {
        return _hashProposal(callDatas_[0]);
    }

    function hashProposal(bytes memory callData_) external view returns (uint256 proposalId_) {
        return _hashProposal(callData_);
    }

    function name() external view returns (string memory name_) {
        return _name;
    }

    function proposalDeadline(uint256 proposalId_) external view returns (uint256 deadline_) {
        return _getVoteEnd(_proposals[proposalId_].voteStart);
    }

    function proposalProposer(uint256 proposalId_) external view returns (address proposer_) {
        return _proposals[proposalId_].proposer;
    }

    function proposalSnapshot(uint256 proposalId_) external view returns (uint256 snapshot_) {
        return _proposals[proposalId_].voteStart - 1;
    }

    function proposalThreshold() external pure returns (uint256 threshold_) {
        return 0;
    }

    function state(uint256 proposalId_) public view virtual returns (ProposalState state_);

    function votingDelay() public view virtual returns (uint256 votingDelay_);

    function votingPeriod() public view virtual returns (uint256 votingPeriod_);

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal returns (uint256 weight_) {
        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            // NOTE: This only gives an accurate "weight" if all proposals are the same type.
            // TODO: There is a more efficient way to do this since each `_castVote` call will re-query chain storage.
            (weight_, ) = _castVote(voter_, proposalIds_[index_], supports_[index_]);
        }
    }

    function _castVote(
        address voter_,
        uint256 proposalId_,
        uint8 support_
    ) internal virtual returns (uint256 weight_, uint256 snapshot_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        ProposalState state_ = state(proposalId_);

        if (state_ != ProposalState.Active) revert ProposalNotActive(state_);

        if (hasVoted[proposalId_][voter_]) revert AlreadyVoted();

        hasVoted[proposalId_][voter_] = true;

        snapshot_ = proposal_.voteStart - 1;

        weight_ = getVotes(voter_, snapshot_);

        if (VoteType(support_) == VoteType.No) {
            proposal_.noWeight += weight_;
        } else {
            proposal_.yesWeight += weight_;
        }

        // TODO: Check if ignoring the voter's reason breaks community compatibility of this event.
        emit VoteCast(voter_, proposalId_, support_, weight_, "");
    }

    function _createProposal(uint256 proposalId_, uint256 voteStart_) internal virtual;

    function _execute(bytes memory callData_, uint256 voteStart_) internal virtual returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(callData_, voteStart_);

        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.voteStart != voteStart_) return 0;

        if (state(proposalId_) != ProposalState.Succeeded) return 0;

        proposal_.executed = true;

        emit ProposalExecuted(proposalId_);

        (bool success_, bytes memory data_) = address(this).call(callData_);

        if (!success_) revert ExecutionFailed(data_);
    }

    function _propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) internal returns (uint256 proposalId_, uint256 voteStart_) {
        if (targets_.length != 1) revert InvalidTargetsLength();
        if (targets_[0] != address(this)) revert InvalidTarget();

        if (values_.length != 1) revert InvalidValuesLength();
        if (values_[0] != 0) revert InvalidValue();

        if (callDatas_.length != 1) revert InvalidCallDatasLength();

        _revertIfInvalidCalldata(callDatas_[0]);

        voteStart_ = _getVoteStart(clock());

        proposalId_ = _hashProposal(callDatas_[0], voteStart_);

        if (_proposals[proposalId_].voteStart != 0) revert ProposalExists();

        _createProposal(proposalId_, voteStart_);

        emit ProposalCreated(
            proposalId_,
            msg.sender,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            _getVoteEnd(voteStart_),
            description_
        );
    }

    /**
     * @dev This function tries to execute a proposal based on the call data and a range of possible vote starts. This
     *      is needed due to the fact that proposalId's are generated based on the call data and vote start time, and so
     *      an executed function will need this in order to attempt to find and execute a proposal given a known range
     *      of possible vote start times which depends on the how the inheriting implementation handles determine the
     *      vote start time and expiry of proposals based on the time of the proposal creation.
     */
    function _tryExecute(
        bytes memory callData_,
        uint256 latestVoteStart_,
        uint256 earliestVoteStart_
    ) internal returns (uint256 proposalId_) {
        if (msg.value != 0) revert InvalidValue();

        while (latestVoteStart_ >= earliestVoteStart_) {
            proposalId_ = _execute(callData_, latestVoteStart_);

            if (latestVoteStart_ == 0) break;

            --latestVoteStart_;

            if (proposalId_ != 0) return proposalId_;
        }

        revert ProposalCannotBeExecuted();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getBallotDigest(uint256 proposalId_, uint8 support_) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId_, support_)));
    }

    function _getBallotsDigest(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOTS_TYPEHASH, proposalIds_, supports_)));
    }

    function _getTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        return IEpochBasedVoteToken(voteToken).pastTotalSupply(timepoint_);
    }

    function _getVoteEnd(uint256 voteStart_) internal view returns (uint48 voteEnd_) {
        return uint48(voteStart_ + votingPeriod());
    }

    function _getVoteStart(uint256 proposalClock_) internal view returns (uint48 voteStart_) {
        return uint48(proposalClock_ + votingDelay());
    }

    function _hashProposal(bytes memory callData_) internal view returns (uint256 proposalId_) {
        return _hashProposal(callData_, _getVoteStart(clock()));
    }

    function _hashProposal(bytes memory callData_, uint256 voteStart_) internal view returns (uint256 proposalId_) {
        return uint256(keccak256(abi.encode(callData_, voteStart_, address(this))));
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure virtual;

    function _revertIfNotSelf() internal view {
        if (msg.sender != address(this)) revert NotSelf();
    }
}
