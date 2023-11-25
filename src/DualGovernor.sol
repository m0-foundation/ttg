// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IDualGovernor } from "./interfaces/IDualGovernor.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";
import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { PureEpochs } from "./PureEpochs.sol";
import { ERC712 } from "./ERC712.sol";

// TODO: Expose `_proposals`?
// TODO: Implement `QuorumNumeratorUpdated` (`quorumNumerator`, `quorumDenominator`) in the DualGovernor contract.
// TODO: Swap address in list.
// TODO: Cash toggle will be an emergency proposal.
// TODO: Better hash function for uniqueness per epoch.
// TODO: Get rid of reasons amd descriptions? Possibly even the exposed functions themselves.
// TODO: Investigate splitting Governor into 3 simpler Governors.
// TODO: Emit an event in the Governor or Power Token when a voter has voted on all standard proposals in an epoch.

contract DualGovernor is IDualGovernor, ERC712 {
    // TODO: Ensure this is correctly compacted into one slot.
    // TODO: Can pop proposer out of this struct and into its own mapping as its mostly useless.
    struct Proposal {
        ProposalType proposalType;
        uint16 voteStart;
        uint16 voteEnd;
        bool executed;
        address proposer;
        uint16 thresholdRatio;
        uint256 noWeight;
        uint256 yesWeight;
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

    address internal immutable _powerToken;
    address internal immutable _registrar;
    address internal immutable _vault;
    address internal immutable _zeroToken;

    uint256 internal immutable _maxTotalZeroRewardPerActiveEpoch;

    address internal _cashToken;

    uint256 internal _proposalFee;

    uint16 internal _powerTokenThresholdRatio;
    uint16 internal _zeroTokenThresholdRatio;

    mapping(address token => bool allowed) internal _allowedCashTokens;

    mapping(uint256 proposalId => Proposal proposal) internal _proposals;

    mapping(uint256 proposalId => mapping(address voter => bool hasVoted)) internal _hasVoted;

    mapping(uint256 epoch => uint256 count) internal _standardProposals;

    mapping(uint256 epoch => mapping(address voter => uint256 count)) internal _standardProposalsVotedOn;

    modifier onlySelf() {
        if (msg.sender != address(this)) revert NotSelf();

        _;
    }

    constructor(
        address registrar_,
        address powerToken_,
        address zeroToken_,
        address vault_,
        address[] memory allowedCashTokens_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_,
        uint16 powerTokenThresholdRatio_,
        uint16 zeroTokenThresholdRatio_
    ) ERC712("DualGovernor") {
        if ((_registrar = registrar_) == address(0)) revert ZeroRegistrarAddress();
        if ((_powerToken = powerToken_) == address(0)) revert InvalidPowerTokenAddress();
        if ((_zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
        if ((_vault = vault_) == address(0)) revert ZeroVaultAddress();

        _proposalFee = proposalFee_;
        _maxTotalZeroRewardPerActiveEpoch = maxTotalZeroRewardPerActiveEpoch_;

        _powerTokenThresholdRatio = powerTokenThresholdRatio_;
        _zeroTokenThresholdRatio = zeroTokenThresholdRatio_;

        if (allowedCashTokens_.length == 0) revert NoAllowedCashTokens();

        for (uint256 index_; index_ < allowedCashTokens_.length; ++index_) {
            address allowedCashToken_ = allowedCashTokens_[index_];

            if (allowedCashToken_ == address(0)) revert ZeroCashTokenAddress();

            _allowedCashTokens[allowedCashToken_] = true;

            if (index_ == 0) {
                _cashToken = allowedCashToken_;
            }
        }
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function castVote(uint256 proposalId_, uint8 support_) external returns (uint256 weight_) {
        return _castVote(msg.sender, proposalId_, support_);
    }

    function castVotes(uint256[] calldata proposalIds_, uint8[] calldata supports_) external returns (uint256 weight_) {
        return _castVotes(msg.sender, proposalIds_, supports_);
    }

    function castVoteWithReason(
        uint256 proposalId_,
        uint8 support_,
        string calldata reason_
    ) external returns (uint256 weight_) {
        return _castVote(msg.sender, proposalId_, support_);
    }

    function castVotesWithReason(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata reasons_
    ) external returns (uint256 weight_) {
        return _castVotes(msg.sender, proposalIds_, supports_);
    }

    function castVoteBySig(
        uint256 proposalId_,
        uint8 support_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return _castVote(_getSigner(_getBallotDigest(proposalId_, support_), v_, r_, s_), proposalId_, support_);
    }

    function castVotesBySig(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return _castVotes(_getSigner(_getBallotsDigest(proposalIds_, supports_), v_, r_, s_), proposalIds_, supports_);
    }

    function castVoteWithReasonBySig(
        uint256 proposalId_,
        uint8 support_,
        string calldata reason_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint256 weight_) {
        return
            _castVote(
                _getSigner(_getBallotWithReasonDigest(proposalId_, support_, reason_), v_, r_, s_),
                proposalId_,
                support_
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
        return
            _castVotes(
                _getSigner(_getBallotsWithReasonDigest(proposalIds_, supports_, reasons_), v_, r_, s_),
                proposalIds_,
                supports_
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

    // TODO: If PowerToken has "future active checkpoints", then this would not be needed.
    function markEpochActive() external {
        if (_standardProposals[PureEpochs.currentEpoch()] == 0) revert EpochHasNoProposals();

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

        proposalId_ = hashProposal(targets_, values_, calldatas_, keccak256(bytes(description_)));

        if (_proposals[proposalId_].voteStart != 0) revert ProposalExists();

        bytes4 func_ = bytes4(calldatas_[0]);
        uint256 currentEpoch_ = PureEpochs.currentEpoch();
        ProposalType proposalType_ = _getProposalType(func_);

        (uint256 voteStart_, uint256 voteEnd_) = (proposalType_ == ProposalType.Standard)
            ? (currentEpoch_ + votingDelay(), currentEpoch_ + votingDelay())
            : (currentEpoch_, currentEpoch_ + 1);

        if (proposalType_ == ProposalType.Standard) {
            _standardProposals[voteStart_] += 1;

            // NOTE: Not calling `distribute` on vault since:
            //         - anyone can do it, anytime
            //         - `DualGovernor` should not need to know how the vault works
            ERC20Helper.transferFrom(_cashToken, msg.sender, _vault, _proposalFee);
        }

        _proposals[proposalId_] = Proposal({
            proposalType: proposalType_,
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: false,
            proposer: msg.sender,
            thresholdRatio: proposalType_ == ProposalType.Zero ? _zeroTokenThresholdRatio : _powerTokenThresholdRatio,
            noWeight: 0,
            yesWeight: 0
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
        return "mode=epoch";
    }

    function COUNTING_MODE() external pure returns (string memory countingMode_) {
        // NOTE: This may be wrong/lacking, in more ways than one.
        // TODO: Implement.
    }

    function cashToken() external view returns (address cashToken_) {
        return _cashToken;
    }

    function clock() external view returns (uint48 clock_) {
        return uint48(PureEpochs.currentEpoch());
    }

    function getProposal(
        uint256 proposalId_
    )
        external
        view
        returns (
            ProposalType proposalType_,
            uint16 voteStart_,
            uint16 voteEnd_,
            bool executed_,
            ProposalState state_,
            uint16 thresholdRatio_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        proposalType_ = proposal_.proposalType;
        voteStart_ = proposal_.voteStart;
        voteEnd_ = proposal_.voteEnd;
        executed_ = proposal_.executed;
        state_ = state(proposalId_);
        thresholdRatio_ = proposal_.thresholdRatio;
        proposer_ = proposal_.proposer;
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
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
        return uint256(keccak256(abi.encode(targets_, values_, calldatas_, descriptionHash_)));
    }

    function hasVotedOnAllStandardProposals(address voter_, uint256 epoch_) external view returns (bool hasVoted_) {
        return _standardProposalsVotedOn[epoch_][voter_] == _standardProposals[epoch_];
    }

    function hasVoted(uint256 proposalId_, address account_) external view returns (bool hasVoted_) {
        return _hasVoted[proposalId_][account_];
    }

    function isAllowedCashToken(address token_) external view returns (bool isAllowed_) {
        return _allowedCashTokens[token_];
    }

    function name() external view returns (string memory name_) {
        return _name;
    }

    function numberOfStandardProposalsAt(uint256 epoch_) external view returns (uint256 count_) {
        return _standardProposals[epoch_];
    }

    function numberOfStandardProposalsVotedOnAt(uint256 epoch_, address voter_) external view returns (uint256 count_) {
        return _standardProposalsVotedOn[epoch_][voter_];
    }

    function powerToken() external view returns (address powerToken_) {
        return _powerToken;
    }

    function powerTokenThresholdRatio() external view returns (uint256 thresholdRatio_) {
        return _powerTokenThresholdRatio;
    }

    function proposalDeadline(uint256 proposalId_) external view returns (uint256 deadline_) {
        return _proposals[proposalId_].voteEnd;
    }

    function proposalFee() external view returns (uint256 proposalFee_) {
        return _proposalFee;
    }

    function proposalProposer(uint256 proposalId_) external view returns (address proposer_) {
        return _proposals[proposalId_].proposer;
    }

    function proposalSnapshot(uint256 proposalId_) external view returns (uint256 snapshot_) {
        return _proposals[proposalId_].voteStart - 1;
    }

    function quorum(uint256 timepoint_) external pure returns (uint256 quorum_) {
        // NOTE: This may be wrong/lacking, in more ways than one.
        // TODO: Implement.
    }

    function registrar() external view returns (address registrar_) {
        return _registrar;
    }

    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256 reward_) {
        return _maxTotalZeroRewardPerActiveEpoch;
    }

    function state(uint256 proposalId_) public view returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        bool isStandard_ = proposal_.proposalType == ProposalType.Standard;
        uint256 voteEnd_ = proposal_.voteEnd;

        if (isStandard_ && currentEpoch_ <= voteEnd_) return ProposalState.Active;

        if (!_proposalCanSucceed(proposal_)) return ProposalState.Defeated;

        if (currentEpoch_ > voteEnd_ && !_proposalIsSucceeding(proposal_)) return ProposalState.Defeated;

        if (currentEpoch_ > voteEnd_ + (isStandard_ ? 2 : 0)) return ProposalState.Expired;

        if (!_proposalCanBeDefeated(proposal_)) return ProposalState.Succeeded;

        // NOTE: This last line could be the following and still work (however, the one used is more obvious):
        //       `return isStandard_ ? ProposalState.Succeeded : ProposalState.Active;`
        //       `return _proposalIsSucceeding(proposal_) ? ProposalState.Succeeded : ProposalState.Active;`
        return currentEpoch_ > voteEnd_ ? ProposalState.Succeeded : ProposalState.Active;
    }

    function vault() external view returns (address vault_) {
        return _vault;
    }

    function votingDelay() public view returns (uint256 votingDelay_) {
        // NOTE: This is only valid for Power proposals.
        return _isVotingEpoch(PureEpochs.currentEpoch()) ? 2 : 1;
    }

    function votingPeriod() external pure returns (uint256 votingPeriod_) {
        // NOTE: This is only valid for Power proposals.
        return 1;
    }

    function zeroToken() external view returns (address zeroToken_) {
        return _zeroToken;
    }

    function zeroTokenThresholdRatio() external view returns (uint256 thresholdRatio_) {
        return _zeroTokenThresholdRatio;
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

    function emergencySetProposalFee(uint256 newProposalFee_) external onlySelf {
        _setProposalFee(newProposalFee_);
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

    function setCashToken(address newCashToken_, uint256 newProposalFee_) external onlySelf {
        _setCashToken(newCashToken_, newProposalFee_);
    }

    function setProposalFee(uint256 newProposalFee_) external onlySelf {
        _setProposalFee(newProposalFee_);
    }

    function setPowerTokenThresholdRatio(uint16 newThresholdRatio_) external onlySelf {
        emit PowerTokenThresholdRatioSet(_powerTokenThresholdRatio = newThresholdRatio_);
    }

    function setZeroTokenThresholdRatio(uint16 newThresholdRatio_) external onlySelf {
        emit ZeroTokenThresholdRatioSet(_zeroTokenThresholdRatio = newThresholdRatio_);
    }

    function updateConfig(bytes32 key_, bytes32 value_) external onlySelf {
        _updateConfig(key_, value_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _addToList(bytes32 list_, address account_) internal {
        IRegistrar(_registrar).addToList(list_, account_);
    }

    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_
    ) internal returns (uint256 weight_) {
        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            // NOTE: This only gives an accurate "weight" if all proposals are the same type.
            // TODO: There is a more efficient way to do this since each `_castVote` call will re-query chain storage.
            weight_ = _castVote(voter_, proposalIds_[index_], supports_[index_]);
        }
    }

    function _castVote(address voter_, uint256 proposalId_, uint8 support_) internal returns (uint256 weight_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        ProposalState state_ = state(proposalId_);

        if (state_ != ProposalState.Active) revert ProposalNotActive(state_);

        if (_hasVoted[proposalId_][voter_]) revert AlreadyVoted();

        _hasVoted[proposalId_][voter_] = true;

        uint256 snapshot_ = proposal_.voteStart - 1;

        ProposalType proposalType_ = proposal_.proposalType;

        weight_ = proposalType_ == ProposalType.Zero
            ? _getZeroTokenWeight(voter_, snapshot_)
            : _getPowerTokenWeight(voter_, snapshot_);

        if (VoteType(support_) == VoteType.No) {
            proposal_.noWeight += weight_;
        } else {
            proposal_.yesWeight += weight_;
        }

        emit VoteCast(voter_, proposalId_, support_, weight_, "");

        // Only Power proposals are mandatory and result in inflation if they are all voted on.
        if (proposalType_ != ProposalType.Standard) return weight_;

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 numberOfProposalsVotedOn_ = ++_standardProposalsVotedOn[currentEpoch_][voter_];

        if (numberOfProposalsVotedOn_ != _standardProposals[currentEpoch_]) return weight_;

        IPowerToken(_powerToken).markParticipation(voter_);

        IZeroToken(_zeroToken).mint(
            voter_,
            (_maxTotalZeroRewardPerActiveEpoch * weight_) / _getPowerTokenTotalSupply(snapshot_)
        );
    }

    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(_registrar).removeFromList(list_, account_);
    }

    function _setCashToken(address newCashToken_, uint256 newProposalFee_) internal {
        if (!_allowedCashTokens[newCashToken_]) revert InvalidCashToken();

        emit CashTokenSet(_cashToken = newCashToken_);

        IPowerToken(_powerToken).setNextCashToken(newCashToken_);

        _setProposalFee(newProposalFee_);
    }

    function _setProposalFee(uint256 newProposalFee_) internal {
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

    function _getPowerTokenTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        totalSupply_ = IEpochBasedVoteToken(_powerToken).totalSupplyAt(timepoint_);
    }

    function _getPowerTokenWeight(address account_, uint256 timepoint_) internal view returns (uint256 weight_) {
        weight_ = IEpochBasedVoteToken(_powerToken).getPastVotes(account_, timepoint_);
    }

    function _getProposalType(bytes4 func_) internal pure returns (ProposalType proposalType_) {
        if (
            func_ == this.addToList.selector ||
            func_ == this.removeFromList.selector ||
            func_ == this.setProposalFee.selector ||
            func_ == this.updateConfig.selector
        ) return ProposalType.Standard;

        if (
            func_ == this.emergencyAddToList.selector ||
            func_ == this.emergencyRemoveFromList.selector ||
            func_ == this.emergencySetProposalFee.selector ||
            func_ == this.emergencyUpdateConfig.selector
        ) return ProposalType.Emergency;

        if (
            func_ == this.setPowerTokenThresholdRatio.selector ||
            func_ == this.setZeroTokenThresholdRatio.selector ||
            func_ == this.setCashToken.selector ||
            func_ == this.reset.selector
        ) return ProposalType.Zero;

        revert InvalidProposalType();
    }

    function _getSigner(bytes32 digest_, uint8 v_, bytes32 r_, bytes32 s_) internal view returns (address signer_) {
        signer_ = _getSigner(digest_, type(uint256).max, v_, r_, s_); // NOTE: No expiration.
    }

    function _getTotalSupply(
        ProposalType proposalType_,
        uint256 timepoint_
    ) internal view returns (uint256 totalSupply_) {
        return
            proposalType_ == ProposalType.Zero
                ? _getZeroTokenTotalSupply(timepoint_)
                : _getPowerTokenTotalSupply(timepoint_);
    }

    function _getZeroTokenTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        totalSupply_ = IEpochBasedVoteToken(_zeroToken).totalSupplyAt(timepoint_);
    }

    function _getZeroTokenWeight(address account_, uint256 timepoint_) internal view returns (uint256 weight_) {
        weight_ = IEpochBasedVoteToken(_zeroToken).getPastVotes(account_, timepoint_);
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1;
    }

    function _proposalCanBeDefeated(Proposal storage proposal_) internal view returns (bool voteCanFail_) {
        uint256 totalSupply_ = _getTotalSupply(proposal_.proposalType, proposal_.voteStart - 1);

        return
            proposal_.proposalType == ProposalType.Standard
                ? totalSupply_ > 2 * proposal_.yesWeight
                : proposal_.yesWeight * ONE < proposal_.thresholdRatio * totalSupply_;
    }

    function _proposalCanSucceed(Proposal storage proposal_) internal view returns (bool voteCanSucceed_) {
        uint256 totalSupply_ = _getTotalSupply(proposal_.proposalType, proposal_.voteStart - 1);

        return
            proposal_.proposalType == ProposalType.Standard
                ? totalSupply_ > 2 * proposal_.noWeight
                : (totalSupply_ - proposal_.noWeight) * ONE >= proposal_.thresholdRatio * totalSupply_;
    }

    function _proposalIsSucceeding(Proposal storage proposal_) internal view returns (bool voteSucceeded_) {
        if (proposal_.proposalType == ProposalType.Standard) return proposal_.yesWeight > proposal_.noWeight;

        uint256 totalSupply_ = _getTotalSupply(proposal_.proposalType, proposal_.voteStart - 1);

        return (proposal_.yesWeight * ONE) / totalSupply_ >= proposal_.thresholdRatio;
    }
}
