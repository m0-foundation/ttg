// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IDualGovernor } from "./interfaces/IDualGovernor.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";
import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { PureEpochs } from "./PureEpochs.sol";
import { ERC712 } from "./ERC712.sol";

// TODO: expose `_proposals` and `_tallies`?

contract DualGovernor is IDualGovernor, ERC712 {
    // TODO: Ensure this is correctly compacted into one slot.
    struct Proposal {
        address proposer;
        uint16 voteStart;
        uint16 voteEnd;
        bool executed;
        bool canceled;
        ProposalType proposalType;
    }

    struct Tallies {
        uint256 noPowerTokenWeight;
        uint256 yesPowerTokenWeight;
        uint256 noZeroTokenWeight;
        uint256 yesZeroTokenWeight;
    }

    uint256 public constant ONE = 10_000;

    // keccak256("Ballot(uint256 proposalId,uint8 support)")
    bytes32 public constant BALLOT_TYPEHASH = 0x150214d74d59b7d1e90c73fc22ef3d991dd0a76b046543d4d80ab92d2a50328f;

    // keccak256("Ballots(uint256[] proposalIds,uint8[] supports)")
    bytes32 public constant BALLOTS_TYPEHASH = 0xb20d034e2b92f6b024d089dda1efe87253106a2d1a82b2a19ec386d383e7aa32;

    // keccak256("Ballot(uint256 proposalId,uint8 support,string reason)")
    bytes32 public constant BALLOT_WITH_REASON_TYPEHASH =
        0x61550a894bd041be3cb7ce7ed747abee6eca83842eee10ff98891711d55a697f;

    // keccak256("Ballots(uint256[] proposalIds,uint8[] supports,string[] reasons)")
    bytes32 public constant BALLOTS_WITH_REASON_TYPEHASH =
        0x4a8d949a35428f9a377e2e2b89d8883cda4fbc8055ff94f098fc4955c82d42ff;

    address internal immutable _cash;
    address internal immutable _registrar;
    address internal immutable _zeroToken;
    address internal immutable _powerToken;

    uint256 internal _proposalFee;
    uint256 internal _minProposalFee;
    uint256 internal _maxProposalFee;

    uint256 internal _reward;

    uint16 internal _zeroTokenQuorumRatio;
    uint16 internal _powerTokenQuorumRatio;

    mapping(uint256 proposalId => Proposal proposal) internal _proposals;

    mapping(uint256 proposalId => Tallies tallies) internal _tallies;

    mapping(uint256 proposalId => mapping(address voter => bool hasVoted)) internal _hasVoted;

    mapping(uint256 epoch => uint256 count) internal _numberOfProposals;

    mapping(uint256 epoch => mapping(address voter => uint256 count)) internal _numberOfProposalsVotedOn;

    modifier onlySelf() {
        if (msg.sender != address(this)) revert NotSelf();

        _;
    }

    constructor(
        address cash_,
        address registrar_,
        address zeroToken_,
        address powerToken_,
        uint256 proposalFee_,
        uint256 minProposalFee_,
        uint256 maxProposalFee_,
        uint256 reward_,
        uint16 zeroTokenQuorumRatio_,
        uint16 powerTokenQuorumRatio_
    ) ERC712("DualGovernor") {
        if ((_cash = cash_) == address(0)) revert ZeroCashAddress();
        if ((_registrar = registrar_) == address(0)) revert ZeroRegistrarAddress();
        if ((_zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
        if ((_powerToken = powerToken_) == address(0)) revert InvalidPowerTokenAddress();

        // TODO: Maybe call internal functions to reused validation logic, if any.
        _proposalFee = proposalFee_;
        _minProposalFee = minProposalFee_;
        _maxProposalFee = maxProposalFee_;
        _reward = reward_;

        _zeroTokenQuorumRatio = zeroTokenQuorumRatio_;
        _powerTokenQuorumRatio = powerTokenQuorumRatio_;
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function castVote(uint256 proposalId_, uint8 support_) external returns (uint256 weight_) {
        weight_ = _castVote(msg.sender, proposalId_, support_);
    }

    function castVotes(uint256[] calldata proposalIds_, uint8[] calldata supports_) external returns (uint256 weight_) {
        weight_ = _castVotes(msg.sender, proposalIds_, supports_);
    }

    function castVoteWithReason(
        uint256 proposalId_,
        uint8 support_,
        string calldata reason_
    ) external returns (uint256 weight_) {
        weight_ = _castVote(msg.sender, proposalId_, support_, reason_);
    }

    function castVotesWithReason(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata reasons_
    ) external returns (uint256 weight_) {
        weight_ = _castVotes(msg.sender, proposalIds_, supports_, reasons_);
    }

    function castVoteBySig(
        uint256 proposalId_,
        uint8 support_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        weight_ = _castVote(_getSigner(_getBallotDigest(proposalId_, support_), v_, r_, s_), proposalId_, support_);
    }

    function castVotesBySig(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        weight_ = _castVotes(
            _getSigner(_getBallotsDigest(proposalIds_, supports_), v_, r_, s_),
            proposalIds_,
            supports_
        );
    }

    function castVoteWithReasonBySig(
        uint256 proposalId_,
        uint8 support_,
        string calldata reason_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        weight_ = _castVote(
            _getSigner(_getBallotWithReasonDigest(proposalId_, support_, reason_), v_, r_, s_),
            proposalId_,
            support_,
            reason_
        );
    }

    function castVotesWithReasonBySig(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata reasons_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        weight_ = _castVotes(
            _getSigner(_getBallotsWithReasonDigest(proposalIds_, supports_, reasons_), v_, r_, s_),
            proposalIds_,
            supports_,
            reasons_
        );
    }

    function execute(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) external payable returns (uint256 proposalId_) {
        proposalId_ = hashProposal(targets_, values_, calldatas_, descriptionHash_);

        ProposalState status_ = state(proposalId_);

        if (status_ != ProposalState.Succeeded) revert ProposalNotSuccessful();

        _proposals[proposalId_].executed = true;

        emit ProposalExecuted(proposalId_);

        (bool success_, bytes memory data_) = targets_[0].call(calldatas_[0]);

        if (!success_) revert ExecutionFailed(data_);
    }

    function markEpochActive() external {
        if (_numberOfProposals[PureEpochs.currentEpoch()] == 0) revert EpochHasNoProposals();

        IPowerToken(_powerToken).markEpochActive();
    }

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        string memory description_
    ) external returns (uint256 proposalId_) {
        if (targets_.length != 1) revert InvalidTargetsLength();
        if (targets_[0] != address(this)) revert InvalidTarget();

        if (values_.length != 1) revert InvalidValuesLength();
        if (values_[0] != 0) revert InvalidValue();

        if (calldatas_.length != 1) revert InvalidCalldatasLength();

        ERC20Helper.transferFrom(_cash, msg.sender, address(this), _proposalFee); // TODO: Send elsewhere.

        proposalId_ = hashProposal(targets_, values_, calldatas_, keccak256(bytes(description_)));

        if (_proposals[proposalId_].proposer != address(0)) revert ProposalExists();

        bytes4 func_ = bytes4(calldatas_[0]);
        uint256 currentEpoch_ = PureEpochs.currentEpoch();
        ProposalType proposalType_ = _getProposalType(func_);

        (uint256 voteStart_, uint256 voteEnd_) = (proposalType_ == ProposalType.Emergency ||
            proposalType_ == ProposalType.Zero)
            ? (currentEpoch_, currentEpoch_ + 1)
            : (currentEpoch_ + votingDelay(), currentEpoch_ + votingDelay() + 1);

        if (proposalType_ == ProposalType.Power) {
            _numberOfProposals[voteStart_] += 1;
        }

        _proposals[proposalId_] = Proposal({
            proposer: msg.sender,
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: false,
            canceled: false,
            proposalType: proposalType_
        });

        emit ProposalCreated(
            proposalId_,
            msg.sender,
            targets_,
            values_,
            new string[](targets_.length), // TODO: `string[] signatures` is silly.
            calldatas_,
            voteStart_,
            voteEnd_,
            description_
        );
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        clockMode_ = "mode=epoch";
    }

    function COUNTING_MODE() external pure returns (string memory countingMode_) {
        // NOTE: This may be wrong/lacking, in more ways than one.
        // TODO: Implement.
    }

    function cash() external view returns (address cash_) {
        cash_ = _cash;
    }

    function clock() external view returns (uint48 clock_) {
        clock_ = uint48(PureEpochs.currentEpoch());
    }

    function getVotes(address account_, uint256 timepoint_) external view returns (uint256 weight_) {
        // TODO: Implement?
    }

    function hashProposal(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory calldatas_,
        bytes32 descriptionHash_
    ) public pure returns (uint256 proposalId_) {
        // TODO: replace `descriptionHash_` with the epoch to prevent duplication.
        proposalId_ = uint256(keccak256(abi.encode(targets_, values_, calldatas_, descriptionHash_)));
    }

    function hasVoted(uint256 proposalId_, address account_) external view returns (bool hasVoted_) {
        hasVoted_ = _hasVoted[proposalId_][account_];
    }

    function maxProposalFee() external view returns (uint256 maxProposalFee_) {
        maxProposalFee_ = _maxProposalFee;
    }

    function minProposalFee() external view returns (uint256 minProposalFee_) {
        minProposalFee_ = _minProposalFee;
    }

    function name() external view returns (string memory name_) {
        name_ = _name;
    }

    function numberOfProposals(uint256 epoch_) external view returns (uint256 numberOfProposals_) {
        numberOfProposals_ = _numberOfProposals[epoch_];
    }

    function numberOfProposalsVotedOn(
        uint256 epoch_,
        address voter_
    ) external view returns (uint256 numberOfProposalsVotedOn_) {
        numberOfProposalsVotedOn_ = _numberOfProposalsVotedOn[epoch_][voter_];
    }

    function powerToken() external view returns (address powerToken_) {
        powerToken_ = _powerToken;
    }

    function powerTokenQuorumRatio() external view returns (uint256 powerTokenQuorumRatio_) {
        powerTokenQuorumRatio_ = _powerTokenQuorumRatio;
    }

    function proposalDeadline(uint256 proposalId_) external view returns (uint256 deadline_) {
        deadline_ = _proposals[proposalId_].voteEnd;
    }

    function proposalFee() external view returns (uint256 proposalFee_) {
        proposalFee_ = _proposalFee;
    }

    function proposalProposer(uint256 proposalId_) external view returns (address proposer_) {
        proposer_ = _proposals[proposalId_].proposer;
    }

    function proposalSnapshot(uint256 proposalId_) external view returns (uint256 snapshot_) {
        snapshot_ = _proposals[proposalId_].voteStart - 1;
    }

    function quorum(uint256 timepoint_) external pure returns (uint256 quorum_) {
        // NOTE: This is only valid for Power proposals.
        quorum_ = 0;
    }

    function registrar() external view returns (address registrar_) {
        registrar_ = _registrar;
    }

    function reward() external view returns (uint256 reward_) {
        reward_ = _reward;
    }

    function state(uint256 proposalId_) public view returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        uint256 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        if (proposal_.executed) return ProposalState.Executed;

        if (proposal_.canceled) return ProposalState.Canceled;

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        uint256 voteEnd_ = proposal_.voteEnd;

        if (proposal_.proposalType == ProposalType.Emergency || proposal_.proposalType == ProposalType.Zero) {
            if (_quorumReached(proposalId_) && _voteSucceeded(proposalId_)) {
                return currentEpoch_ > voteEnd_ ? ProposalState.Expired : ProposalState.Succeeded;
            }

            if (currentEpoch_ <= voteEnd_) return ProposalState.Active;
        } else {
            if (currentEpoch_ <= voteEnd_) return ProposalState.Active;

            if (_quorumReached(proposalId_) && _voteSucceeded(proposalId_)) {
                return currentEpoch_ > voteEnd_ + 2 ? ProposalState.Expired : ProposalState.Succeeded;
            }
        }

        return ProposalState.Defeated;
    }

    function votingDelay() public view returns (uint256 votingDelay_) {
        // NOTE: This is only valid for non-emergency proposals.
        votingDelay_ = _isVotingEpoch(PureEpochs.currentEpoch()) ? 2 : 1;
    }

    function votingPeriod() external pure returns (uint256 votingPeriod_) {
        votingPeriod_ = 1;
    }

    function zeroToken() external view returns (address zeroToken_) {
        zeroToken_ = _zeroToken;
    }

    function zeroTokenQuorumRatio() external view returns (uint256 zeroTokenQuorumRatio_) {
        zeroTokenQuorumRatio_ = _zeroTokenQuorumRatio;
    }

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    function emergencyAddToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    function emergencyRemoveFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    function emergencyUpdateConfig(bytes32 key_, bytes32 value_) external onlySelf {
        _updateConfig(key_, value_);
    }

    function removeFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    function reset() external onlySelf {
        IRegistrar(_registrar).reset();
    }

    function setProposalFee(uint256 newProposalFee_) external onlySelf {
        _setProposalFee(_minProposalFee, _maxProposalFee, newProposalFee_);
    }

    function setProposalFeeRange(
        uint256 newMinProposalFee_,
        uint256 newMaxProposalFee_,
        uint256 newProposalFee_
    ) external onlySelf {
        if (newMinProposalFee_ > newMaxProposalFee_) revert InvalidProposalFeeRange();

        emit ProposalFeeRangeSet(_minProposalFee = newMinProposalFee_, _maxProposalFee = newMaxProposalFee_);

        _setProposalFee(newMinProposalFee_, newMaxProposalFee_, newProposalFee_);
    }

    function setZeroTokenQuorumRatio(uint16 newZeroTokenQuorumRatio_) external onlySelf {
        emit ZeroTokenQuorumRatioSet(_zeroTokenQuorumRatio = newZeroTokenQuorumRatio_);
    }

    function setPowerTokenQuorumRatio(uint16 newPowerTokenQuorumRatio_) external onlySelf {
        emit PowerTokenQuorumRatioSet(_powerTokenQuorumRatio = newPowerTokenQuorumRatio_);
    }

    function updateConfig(bytes32 key_, bytes32 value_) external onlySelf {
        _updateConfig(key_, value_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal returns (uint256 weight_) {
        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            weight_ = _castVote(voter_, proposalIds_[index_], supports_[index_]);
        }
    }

    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata reasons_
    ) internal returns (uint256 weight_) {
        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            weight_ = _castVote(voter_, proposalIds_[index_], supports_[index_], reasons_[index_]);
        }
    }

    function _castVote(address voter_, uint256 proposalId_, uint8 support_) internal returns (uint256 weight_) {
        weight_ = _castVote(voter_, proposalId_, support_, "");
    }

    function _castVote(
        address voter_,
        uint256 proposalId_,
        uint8 support_,
        string memory reason_
    ) internal returns (uint256 weight_) {
        ProposalState state_ = state(proposalId_);

        if (state_ != ProposalState.Active) revert ProposalIsNotInActiveState(state_);

        if (_hasVoted[proposalId_][voter_]) revert AlreadyVoted();

        _hasVoted[proposalId_][voter_] = true;

        Proposal storage proposal_ = _proposals[proposalId_];
        uint256 snapshot_ = proposal_.voteStart - 1;
        ProposalType proposalType_ = proposal_.proposalType;

        uint256 powerTokenWeight_ = (proposalType_ == ProposalType.Power || proposalType_ == ProposalType.Double)
            ? _getPowerTokenWeight(voter_, snapshot_)
            : 0;

        uint256 zeroTokenWeight_ = (proposalType_ == ProposalType.Zero || proposalType_ == ProposalType.Double)
            ? _getZeroTokenWeight(voter_, snapshot_)
            : 0;

        weight_ = powerTokenWeight_ + zeroTokenWeight_;

        Tallies storage tallies_ = _tallies[proposalId_];

        if (VoteType(support_) == VoteType.No) {
            tallies_.noPowerTokenWeight += powerTokenWeight_;
            tallies_.noZeroTokenWeight += zeroTokenWeight_;
        } else {
            tallies_.yesPowerTokenWeight += powerTokenWeight_;
            tallies_.yesZeroTokenWeight += zeroTokenWeight_;
        }

        // NOTE: `weight_` is technically correct, but not discernable.
        emit VoteCast(voter_, proposalId_, support_, weight_, reason_);

        // Only Power proposals are mandatory and result in inflation if they are all voted on.
        if (proposal_.proposalType != ProposalType.Power) return weight_;

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 numberOfProposalsVotedOn_ = ++_numberOfProposalsVotedOn[currentEpoch_][voter_];

        if (numberOfProposalsVotedOn_ != _numberOfProposals[currentEpoch_]) return weight_;

        IPowerToken(_powerToken).markParticipation(voter_);

        IZeroToken(_zeroToken).mint(voter_, (_reward * powerTokenWeight_) / _getPowerTokenTotalSupply(snapshot_));
    }

    function _addToList(bytes32 list_, address account_) internal {
        IRegistrar(_registrar).addToList(list_, account_);
    }

    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(_registrar).removeFromList(list_, account_);
    }

    function _setProposalFee(uint256 minProposalFee_, uint256 maxProposalFee_, uint256 newProposalFee_) internal {
        if (newProposalFee_ < minProposalFee_ || newProposalFee_ > maxProposalFee_) {
            revert ProposalFeeOutOfRange(minProposalFee_, maxProposalFee_);
        }

        emit ProposalFeeSet(_proposalFee = newProposalFee_);
    }

    function _updateConfig(bytes32 key_, bytes32 value_) internal {
        IRegistrar(_registrar).updateConfig(key_, value_);
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

    function _getBallotWithReasonDigest(
        uint256 proposalId_,
        uint8 support_,
        string calldata reason_
    ) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOT_WITH_REASON_TYPEHASH, proposalId_, support_, reason_)));
    }

    function _getBallotsWithReasonDigest(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata reasons_
    ) internal view returns (bytes32 digest_) {
        digest_ = _getDigest(keccak256(abi.encode(BALLOTS_WITH_REASON_TYPEHASH, proposalIds_, supports_, reasons_)));
    }

    function _getProposalType(bytes4 func_) internal pure returns (ProposalType proposalType_) {
        if (
            func_ == this.addToList.selector ||
            func_ == this.removeFromList.selector ||
            func_ == this.updateConfig.selector ||
            func_ == this.setProposalFee.selector
        ) return ProposalType.Power;

        if (
            func_ == this.emergencyAddToList.selector ||
            func_ == this.emergencyRemoveFromList.selector ||
            func_ == this.emergencyUpdateConfig.selector
        ) return ProposalType.Emergency;

        if (
            func_ == this.setZeroTokenQuorumRatio.selector ||
            func_ == this.setPowerTokenQuorumRatio.selector ||
            func_ == this.setProposalFeeRange.selector
        ) return ProposalType.Double;

        if (func_ == this.reset.selector) return ProposalType.Zero; // TODO: This should be like an emergency.

        revert InvalidProposalType();
    }

    function _getSigner(bytes32 digest_, uint8 v_, bytes32 r_, bytes32 s_) internal view returns (address signer_) {
        signer_ = _getSigner(digest_, type(uint256).max, v_, r_, s_); // NOTE: No expiration.
    }

    function _getZeroTokenWeight(address account_, uint256 timepoint_) internal view returns (uint256 weight_) {
        weight_ = IEpochBasedVoteToken(_zeroToken).getPastVotes(account_, timepoint_);
    }

    function _getPowerTokenWeight(address account_, uint256 timepoint_) internal view returns (uint256 weight_) {
        weight_ = IEpochBasedVoteToken(_powerToken).getPastVotes(account_, timepoint_);
    }

    function _getZeroTokenTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        totalSupply_ = IEpochBasedVoteToken(_zeroToken).totalSupplyAt(timepoint_);
    }

    function _getPowerTokenTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        totalSupply_ = IEpochBasedVoteToken(_powerToken).totalSupplyAt(timepoint_);
    }

    function _isQuorumReached(
        uint256 quorumRatio_,
        uint256 yesVotes_,
        uint256 totalSupply_
    ) internal pure returns (bool quorumReached_) {
        quorumReached_ = (yesVotes_ * ONE) / totalSupply_ >= quorumRatio_;
    }

    function _quorumReached(uint256 proposalId_) internal view returns (bool quorumReached_) {
        Proposal storage proposal_ = _proposals[proposalId_];
        ProposalType proposalType_ = proposal_.proposalType;

        if (proposalType_ == ProposalType.Power) return true;

        Tallies storage tallies_ = _tallies[proposalId_];

        uint256 snapshot_ = proposal_.voteStart - 1;

        if (proposalType_ == ProposalType.Emergency) {
            return
                _isQuorumReached(
                    _powerTokenQuorumRatio,
                    tallies_.yesPowerTokenWeight,
                    _getPowerTokenTotalSupply(snapshot_)
                );
        }

        if (proposal_.proposalType == ProposalType.Double) {
            return
                _isQuorumReached(
                    _powerTokenQuorumRatio,
                    tallies_.yesPowerTokenWeight,
                    _getPowerTokenTotalSupply(snapshot_)
                ) &&
                _isQuorumReached(
                    _zeroTokenQuorumRatio,
                    tallies_.yesZeroTokenWeight,
                    _getZeroTokenTotalSupply(snapshot_)
                );
        }

        if (proposal_.proposalType == ProposalType.Zero) {
            return
                _isQuorumReached(
                    _zeroTokenQuorumRatio,
                    tallies_.yesZeroTokenWeight,
                    _getZeroTokenTotalSupply(snapshot_)
                );
        }
    }

    function _voteSucceeded(uint256 proposalId_) internal view returns (bool voteSucceeded_) {
        Proposal storage proposal_ = _proposals[proposalId_];
        ProposalType proposalType_ = proposal_.proposalType;
        Tallies storage tallies_ = _tallies[proposalId_];

        if (proposalType_ == ProposalType.Power) return tallies_.yesPowerTokenWeight > tallies_.noPowerTokenWeight;

        if (proposalType_ == ProposalType.Zero) return tallies_.yesZeroTokenWeight > tallies_.noZeroTokenWeight;

        return
            tallies_.yesPowerTokenWeight > tallies_.noPowerTokenWeight &&
            tallies_.yesZeroTokenWeight > tallies_.noZeroTokenWeight;
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1;
    }
}
