// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC712 } from "../../lib/common/src/ERC712.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IBatchGovernor } from "./interfaces/IBatchGovernor.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IERC6372 } from "./interfaces/IERC6372.sol";
import { IGovernor } from "./interfaces/IGovernor.sol";

/// @title Extension for Governor with specialized strict proposal parameters, vote batching, and an epoch clock.
abstract contract BatchGovernor is IBatchGovernor, ERC712 {
    /**
     * @notice Proposal struct for storing all relevant proposal information.
     * @param voteStart      The epoch at which voting begins, inclusively.
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
    function castVotes(
        uint256[] calldata proposalIds_,
        uint8[] calldata supportList_
    ) external returns (uint256 weight_) {
        return _castVotes(msg.sender, proposalIds_, supportList_);
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
                _getSignerAndRevertIfInvalidSignature(getBallotDigest(proposalId_, support_), v_, r_, s_),
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
        _revertIfInvalidSignature(voter_, getBallotDigest(proposalId_, support_), signature_);

        return _castVote(voter_, proposalId_, support_);
    }

    /// @inheritdoc IBatchGovernor
    function castVotesBySig(
        uint256[] calldata proposalIds_,
        uint8[] calldata supportList_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return
            _castVotes(
                _getSignerAndRevertIfInvalidSignature(
                    _getBallotsDigest(
                        keccak256(abi.encodePacked(proposalIds_)),
                        keccak256(abi.encodePacked(supportList_))
                    ),
                    v_,
                    r_,
                    s_
                ),
                proposalIds_,
                supportList_
            );
    }

    /// @inheritdoc IBatchGovernor
    function castVotesBySig(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supportList_,
        bytes memory signature_
    ) external returns (uint256 weight_) {
        _revertIfInvalidSignature(
            voter_,
            _getBallotsDigest(keccak256(abi.encodePacked(proposalIds_)), keccak256(abi.encodePacked(supportList_))),
            signature_
        );

        return _castVotes(voter_, proposalIds_, supportList_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    /// @inheritdoc IGovernor
    function hashProposal(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external view returns (uint256) {
        return _hashProposal(callDatas_[0]);
    }

    /// @inheritdoc IBatchGovernor
    function hashProposal(bytes memory callData_) external view returns (uint256) {
        return _hashProposal(callData_);
    }

    /// @inheritdoc IGovernor
    function name() external view returns (string memory) {
        return _name;
    }

    /// @inheritdoc IGovernor
    function proposalDeadline(uint256 proposalId_) external view returns (uint256) {
        return _getVoteEnd(_proposals[proposalId_].voteStart);
    }

    /// @inheritdoc IGovernor
    function proposalProposer(uint256 proposalId_) external view returns (address) {
        return _proposals[proposalId_].proposer;
    }

    /// @inheritdoc IGovernor
    function proposalSnapshot(uint256 proposalId_) external view returns (uint256) {
        return _proposals[proposalId_].voteStart - 1;
    }

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external pure returns (string memory) {
        return "mode=epoch";
    }

    /// @inheritdoc IGovernor
    function COUNTING_MODE() external pure returns (string memory) {
        return "support=for,against&quorum=for";
    }

    /// @inheritdoc IGovernor
    function proposalThreshold() external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC6372
    function clock() public view returns (uint48) {
        return _clock();
    }

    /// @inheritdoc IBatchGovernor
    function getBallotDigest(uint256 proposalId_, uint8 support_) public view returns (bytes32) {
        return _getDigest(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId_, support_)));
    }

    /// @inheritdoc IBatchGovernor
    function getBallotsDigest(
        uint256[] calldata proposalIds_,
        uint8[] calldata supportList_
    ) public view returns (bytes32) {
        return _getBallotsDigest(keccak256(abi.encodePacked(proposalIds_)), keccak256(abi.encodePacked(supportList_)));
    }

    /// @inheritdoc IGovernor
    function getVotes(address account_, uint256 timepoint_) public view returns (uint256) {
        return IEpochBasedVoteToken(voteToken).getPastVotes(account_, timepoint_);
    }

    /// @inheritdoc IGovernor
    function state(uint256 proposalId_) public view virtual returns (ProposalState);

    /// @inheritdoc IGovernor
    function votingDelay() public view returns (uint256) {
        return _votingDelay();
    }

    /// @inheritdoc IGovernor
    function votingPeriod() public view returns (uint256) {
        return _votingPeriod();
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @dev    Cast votes on several proposals for `voter_`.
     * @param  voter_       The address of the voter.
     * @param  proposalIds_ The list of unique proposal IDs being voted on.
     * @param  supportList_ The list of support type per proposal IDs to cast.
     * @return weight_      The number of votes the voter cast on each proposal.
     */
    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supportList_
    ) internal virtual returns (uint256 weight_) {
        if (proposalIds_.length != supportList_.length || proposalIds_.length == 0)
            revert InvalidSupportLength(proposalIds_.length, supportList_.length);

        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            weight_ = _castVote(voter_, proposalIds_[index_], supportList_[index_]);
        }
    }

    /**
     * @dev    Cast votes on proposal for `voter_`.
     * @param  voter_      The address of the voter.
     * @param  proposalId_ The unique identifier of the proposal.
     * @param  support_    The type of support to cast for the proposal.
     * @return weight_     The type of support to cast for each proposal
     */
    function _castVote(address voter_, uint256 proposalId_, uint8 support_) internal returns (uint256 weight_) {
        unchecked {
            // NOTE: Can be done unchecked since `voteStart` is always greater than 0.
            weight_ = getVotes(voter_, _proposals[proposalId_].voteStart - 1);
        }

        _castVote(voter_, weight_, proposalId_, support_);
    }

    /**
     * @dev   Cast `weight_` votes on a proposal with id `proposalId_` for `voter_`.
     * @param voter_      The address of the voter.
     * @param weight_     The number of votes the voter is casting.
     * @param proposalId_ The unique identifier of the proposal.
     * @param support_    The type of support to cast for the proposal.
     */
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

    /**
     * @dev   Creates a new proposal with the given parameters.
     * @param proposalId_ The unique identifier of the proposal.
     * @param voteStart_  The epoch at which the proposal will start collecting votes.
     */
    function _createProposal(uint256 proposalId_, uint16 voteStart_) internal virtual;

    /**
     * @dev    Executes a proposal given its call data and voteStart (which are unique to it).
     * @param  callData_   The call data to execute.
     * @param  voteStart_  The epoch at which the proposal started collecting votes.
     * @return proposalId_ The unique identifier of the proposal that matched the criteria.
     */
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

    /**
     * @dev    Internal handler for making proposals.
     * @param  targets_     An array of addresses that will be called upon the execution.
     * @param  values_      An array of ETH amounts that will be sent to each respective target upon execution.
     * @param  callDatas_   An array of call data used to call each respective target upon execution.
     * @param  description_ The string of the description of the proposal.
     * @return proposalId_  The unique identifier of the proposal.
     * @return voteStart_   The timepoint at which voting on the proposal begins, inclusively.
     */
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
     * @dev    This function tries to execute a proposal based on the call data and a range of possible vote starts.
     *         This is needed due to the fact that proposalId's are generated based on the call data and vote start
     *         time, and so an executed function will need this in order to attempt to find and execute a proposal given
     *         a known range of possible vote start times which depends on how the inheriting implementation
     *         determines the vote start time and expiry of proposals based on the time of the proposal creation.
     * @param  callData_          An array of call data used to call each respective target upon execution.
     * @param  latestVoteStart_   The most recent vote start to use in attempting to search for the proposal.
     * @param  earliestVoteStart_ The least recent vote start to use in attempting to search for the proposal.
     * @return proposalId_        The unique identifier of the most recent proposal that matched the criteria.
     */
    function _tryExecute(
        bytes memory callData_,
        uint16 latestVoteStart_,
        uint16 earliestVoteStart_
    ) internal returns (uint256 proposalId_) {
        if (msg.value != 0) revert InvalidValue();

        if (earliestVoteStart_ == 0) revert InvalidVoteStart(); // Non-existent proposals have a default vote start of 0.

        while (latestVoteStart_ >= earliestVoteStart_) {
            // `proposalId_` will be 0 if no proposal exists for `callData_` and `latestVoteStart_`, or if the proposal
            // is not in  a `Succeeded` state. It will be executed otherwise. (see `_execute`)
            proposalId_ = _execute(callData_, latestVoteStart_--);

            // If the `proposalId_` is not 0, then a proposal matching `callData_` and `latestVoteStart_` was found, in
            // a Succeeded state, and was executed, so return it.
            if (proposalId_ != 0) return proposalId_;
        }

        revert ProposalCannotBeExecuted(); // No proposal matching the criteria was found/executed.
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    /// @dev Returns the current timepoint according to the mode the contract is operating on.
    function _clock() internal view returns (uint16) {
        return PureEpochs.currentEpoch();
    }

    /**
     * @dev    Returns the vote token's total supply at `timepoint`.
     * @param  timepoint_ The clock value at which to query the vote token's total supply.
     * @return The vote token's total supply at the `timepoint` clock value.
     */
    function _getTotalSupply(uint16 timepoint_) internal view returns (uint256) {
        return IEpochBasedVoteToken(voteToken).pastTotalSupply(timepoint_);
    }

    /// @dev Returns the timepoint at which voting would start for a proposal created in current timepoint.
    function _voteStart() internal view returns (uint16) {
        unchecked {
            return _clock() + _votingDelay();
        }
    }

    /**
     * @dev    Returns the timepoint at which voting would end given a timepoint at which voting would start.
     * @param  voteStart_ The clock value at which voting would start, inclusively.
     * @return The clock value at which voting would end, inclusively.
     */
    function _getVoteEnd(uint16 voteStart_) internal view returns (uint16) {
        unchecked {
            return voteStart_ + _votingPeriod();
        }
    }

    /**
     * @notice Returns the ballots digest to be signed, via EIP-712, given an internal digest (i.e. hash struct).
     * @param  proposalIdsHash_ The hash of the list of unique proposal IDs being voted on.
     * @param  supportListHash_ The hash of the list of support type per proposal IDs to cast.
     * @return The digest to be signed.
     */
    function _getBallotsDigest(bytes32 proposalIdsHash_, bytes32 supportListHash_) internal view returns (bytes32) {
        return _getDigest(keccak256(abi.encode(BALLOTS_TYPEHASH, proposalIdsHash_, supportListHash_)));
    }

    /**
     * @dev    Returns the unique identifier for the proposal if it were created at this exact moment.
     * @param  callData_ The single call data used to call this governor upon execution of a proposal.
     * @return The unique identifier for the proposal.
     */
    function _hashProposal(bytes memory callData_) internal view returns (uint256) {
        return _hashProposal(callData_, _voteStart());
    }

    /**
     * @dev    Returns the unique identifier for the proposal if it were to have a given vote start timepoint.
     * @param  callData_  The single call data used to call this governor upon execution of a proposal.
     * @param  voteStart_ The clock value at which voting would start, inclusively.
     * @return The unique identifier for the proposal.
     */
    function _hashProposal(bytes memory callData_, uint16 voteStart_) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(callData_, voteStart_, address(this))));
    }

    /// @dev Reverts if the caller is not the contract itself.
    function _revertIfNotSelf() internal view {
        if (msg.sender != address(this)) revert NotSelf();
    }

    /// @dev Returns the number of clock values that must elapse before voting begins for a newly created proposal.
    function _votingDelay() internal view virtual returns (uint16);

    /// @dev Returns the number of clock values between the vote start and vote end.
    function _votingPeriod() internal view virtual returns (uint16);

    /**
     * @dev   All proposals target this contract itself, and must call one of the listed functions to be valid.
     * @param callData_ The call data to check.
     */
    function _revertIfInvalidCalldata(bytes memory callData_) internal pure virtual;
}
