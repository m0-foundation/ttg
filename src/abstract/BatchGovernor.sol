// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC712 } from "../../lib/common/src/ERC712.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IBatchGovernor } from "./interfaces/IBatchGovernor.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IGovernor } from "./interfaces/IGovernor.sol";

/// @title Extension for Governor with specialized strict proposal parameters, vote batching, and an epoch clock.
abstract contract BatchGovernor is IBatchGovernor, ERC712 {
    /**
     * @notice Proposal struct for storing all relevant proposal information.
     * @param voteStart      The inclusive epoch, at which voting begins.
     *                       i.e. if `voteStart` is 1 and `voteEnd` is 2, then token holders can vote during epochs 1 and 2.
     * @param executed       Whether or not the proposal has been executed.
     * @param proposer       The address of the proposer.
     * @param thresholdRatio The ratio of yes votes required for a proposal to succeed.
     * @param quorumRatio    The ratio of total votes required for a proposal to succeed.
     * @param noWeight       The total number of votes against the proposal.
     * @param yesWeight      The total number of votes for the proposal.
     */
    struct Proposal {
        // 1st slot
        uint16 voteStart;
        bool executed;
        address proposer;
        uint16 thresholdRatio;
        uint16 quorumRatio;
        // 2nd slot
        uint256 noWeight;
        // 3rd slot
        uint256 yesWeight;
    }

    /// @inheritdoc IBatchGovernor
    uint256 public constant ONE = 10_000;

    // keccak256("Ballot(uint256 proposalId,uint8 support)")
    /// @inheritdoc IGovernor
    bytes32 public constant BALLOT_TYPEHASH = 0x150214d74d59b7d1e90c73fc22ef3d991dd0a76b046543d4d80ab92d2a50328f;

    // keccak256("Ballots(uint256[] proposalIds,uint8[] support)")
    /// @inheritdoc IBatchGovernor
    bytes32 public constant BALLOTS_TYPEHASH = 0x17b363a9cc71c97648659dc006723bbea6565fe35148add65f6887abf5158d39;

    /// @inheritdoc IBatchGovernor
    address public immutable voteToken;

    mapping(uint256 proposalId => Proposal proposal) internal _proposals;

    /// @inheritdoc IGovernor
    mapping(uint256 proposalId => mapping(address voter => bool hasVoted)) public hasVoted;

    modifier onlySelf() {
        _revertIfNotSelf();
        _;
    }

    /**
     * @notice Construct a new BatchGovernor contract.
     * @param  name_      The name of the contract. Used to compute EIP712 domain separator.
     * @param  voteToken_ The address of the token used to vote.
     */
    constructor(string memory name_, address voteToken_) ERC712(name_) {
        if ((voteToken = voteToken_) == address(0)) revert InvalidVoteTokenAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IGovernor
    function castVote(uint256 proposalId_, uint8 support_) external returns (uint256 weight_) {
        return _castVote(msg.sender, proposalId_, support_);
    }

    /// @inheritdoc IBatchGovernor
    function castVotes(uint256[] calldata proposalIds_, uint8[] calldata supports_) external returns (uint256 weight_) {
        return _castVotes(msg.sender, proposalIds_, supports_);
    }

    /// @inheritdoc IGovernor
    function castVoteWithReason(
        uint256 proposalId_,
        uint8 support_,
        string calldata
    ) external returns (uint256 weight_) {
        return _castVote(msg.sender, proposalId_, support_);
    }

    /// @inheritdoc IGovernor
    function castVoteBySig(
        uint256 proposalId_,
        uint8 support_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return
            _castVote(
                _getSignerAndRevertIfInvalidSignature(_getBallotDigest(proposalId_, support_), v_, r_, s_),
                proposalId_,
                support_
            );
    }

    /// @inheritdoc IGovernor
    function castVoteBySig(
        address voter_,
        uint256 proposalId_,
        uint8 support_,
        bytes memory signature_
    ) external returns (uint256 weight_) {
        _revertIfInvalidSignature(voter_, _getBallotDigest(proposalId_, support_), signature_);

        return _castVote(voter_, proposalId_, support_);
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
        return _clock();
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

    /// @inheritdoc IGovernor
    function votingDelay() public view returns (uint256 votingDelay_) {
        return _votingDelay();
    }

    /// @inheritdoc IGovernor
    function votingPeriod() public view returns (uint256 votingPeriod_) {
        return _votingPeriod();
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal virtual returns (uint256 weight_) {
        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            weight_ = _castVote(voter_, proposalIds_[index_], supports_[index_]);
        }
    }

    function _castVote(address voter_, uint256 proposalId_, uint8 support_) internal returns (uint256 weight_) {
        unchecked {
            // NOTE: Can be done unchecked since `voteStart` is always greater than 0.
            weight_ = getVotes(voter_, _proposals[proposalId_].voteStart - 1);
        }

        _castVote(voter_, weight_, proposalId_, support_);
    }

    function _castVote(address voter_, uint256 weight_, uint256 proposalId_, uint8 support_) internal virtual {
        ProposalState state_ = state(proposalId_);

        if (state_ != ProposalState.Active) revert ProposalNotActive(state_);

        if (hasVoted[proposalId_][voter_]) revert AlreadyVoted();

        hasVoted[proposalId_][voter_] = true;

        unchecked {
            // NOTE: Can be done unchecked since total supply is less than `type(uint256).max`.
            if (VoteType(support_) == VoteType.No) {
                _proposals[proposalId_].noWeight += weight_;
            } else {
                _proposals[proposalId_].yesWeight += weight_;
            }
        }

        // TODO: Check if ignoring the voter's reason breaks community compatibility of this event.
        emit VoteCast(voter_, proposalId_, support_, weight_, "");
    }

    function _createProposal(uint256 proposalId_, uint16 voteStart_) internal virtual;

    function _execute(bytes memory callData_, uint16 voteStart_) internal virtual returns (uint256 proposalId_) {
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
    ) internal returns (uint256 proposalId_, uint16 voteStart_) {
        if (targets_.length != 1) revert InvalidTargetsLength();
        if (targets_[0] != address(this)) revert InvalidTarget();

        if (values_.length != 1) revert InvalidValuesLength();
        if (values_[0] != 0) revert InvalidValue();

        if (callDatas_.length != 1) revert InvalidCallDatasLength();

        _revertIfInvalidCalldata(callDatas_[0]);

        voteStart_ = _voteStart();

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
        uint16 latestVoteStart_,
        uint16 earliestVoteStart_
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

    function _clock() internal view returns (uint16 clock_) {
        return PureEpochs.currentEpoch();
    }

    function _getBallotDigest(uint256 proposalId_, uint8 support_) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId_, support_)));
    }

    function _getBallotsDigest(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOTS_TYPEHASH, proposalIds_, supports_)));
    }

    function _getTotalSupply(uint16 timepoint_) internal view returns (uint256 totalSupply_) {
        return IEpochBasedVoteToken(voteToken).pastTotalSupply(timepoint_);
    }

    function _voteStart() internal view returns (uint16) {
        unchecked {
            return _clock() + _votingDelay();
        }
    }

    function _getVoteEnd(uint16 voteStart_) internal view returns (uint16) {
        unchecked {
            return voteStart_ + _votingPeriod();
        }
    }

    function _hashProposal(bytes memory callData_) internal view returns (uint256 proposalId_) {
        return _hashProposal(callData_, _voteStart());
    }

    function _hashProposal(bytes memory callData_, uint16 voteStart_) internal view returns (uint256 proposalId_) {
        return uint256(keccak256(abi.encode(callData_, voteStart_, address(this))));
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure virtual;

    function _revertIfNotSelf() internal view {
        if (msg.sender != address(this)) revert NotSelf();
    }

    /**
     * @dev    Returns the number of clock values that must elapse before voting begins for a newly created proposal.
     * @return The voting delay.
     */
    function _votingDelay() internal view virtual returns (uint16);

    /**
     * @dev    Returns the number of clock values between the vote start and vote end.
     * @return The voting period.
     */
    function _votingPeriod() internal view virtual returns (uint16);
}
