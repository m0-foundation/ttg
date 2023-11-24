// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";
import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { PureEpochs } from "./PureEpochs.sol";
import { ERC712 } from "./ERC712.sol";

// TODO: Determine standard way to inform externals about which token can vote.

// TODO: Expose `_proposals`?
// TODO: Implement `QuorumNumeratorUpdated` (`quorumNumerator`, `quorumDenominator`) in the DualGovernor contract.
// TODO: Get rid of reasons and descriptions? Possibly even the exposed functions themselves.
// TODO: Emit an event in the Governor or Power Token when a voter has voted on all standard proposals in an epoch.
// TODO: Consider non-standard simplified versions of governor functions.

contract StandardGovernor is IStandardGovernor, ERC712 {
    // TODO: Ensure this is correctly compacted into one slot.
    // TODO: Consider popping proposer out of this struct and into its own mapping as its mostly useless.
    struct Proposal {
        uint16 voteStart;
        uint16 voteEnd; // TODO: This can be inferred from voteStart.
        bool executed;
        address proposer;
        uint256 noWeight;
        uint256 yesWeight;
    }

    struct ProposalFeeInfo {
        address cashToken;
        uint256 fee;
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

    address internal immutable _emergencyGovernor;
    address internal immutable _registrar;
    address internal immutable _vault;
    address internal immutable _voteToken;
    address internal immutable _zeroGovernor;
    address internal immutable _zeroToken;

    uint256 internal immutable _maxTotalZeroRewardPerActiveEpoch;

    address internal _cashToken;

    uint256 internal _proposalFee;

    mapping(uint256 proposalId => Proposal proposal) internal _proposals;

    mapping(uint256 proposalId => ProposalFeeInfo proposalFee) internal _proposalFees;

    mapping(uint256 proposalId => mapping(address voter => bool hasVoted)) internal _hasVoted;

    mapping(uint256 epoch => uint256 count) internal _numberOfProposals;

    mapping(uint256 epoch => mapping(address voter => uint256 count)) internal _numberOfProposalsVotedOn;

    modifier onlySelf() {
        _revertIfNotSelf();
        _;
    }

    modifier onlyZeroGovernor() {
        _revertIfNotZeroGovernor();
        _;
    }

    modifier onlySelfOrEmergencyGovernor() {
        _revertIfNotSelfOrEmergencyGovernor();
        _;
    }

    constructor(
        address registrar_,
        address voteToken_,
        address emergencyGovernor_,
        address zeroGovernor_,
        address zeroToken_,
        address cashToken_,
        address vault_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) ERC712("StandardGovernor") {
        if ((_registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((_voteToken = voteToken_) == address(0)) revert InvalidVoteTokenAddress();
        if ((_emergencyGovernor = emergencyGovernor_) == address(0)) revert InvalidEmergencyGovernorAddress();
        if ((_zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((_zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
        if ((_vault = vault_) == address(0)) revert InvalidVaultAddress();

        _setCashToken(cashToken_);
        _setProposalFee(proposalFee_);

        _maxTotalZeroRewardPerActiveEpoch = maxTotalZeroRewardPerActiveEpoch_;
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
        string calldata
    ) external returns (uint256 weight_) {
        return _castVote(msg.sender, proposalId_, support_);
    }

    function castVotesWithReason(
        uint256[] calldata proposalIds_,
        uint8[] calldata supports_,
        string[] calldata
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
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external payable returns (uint256 proposalId_) {
        if (msg.value != 0) revert InvalidValue();

        // Proposals have voteStart=N and voteEnd=N, and can be executed only during epochs N+1 and N+2.
        uint256 firstPotentialVoteStart_ = PureEpochs.currentEpoch() - 1;

        proposalId_ = _execute(callDatas_[0], firstPotentialVoteStart_); // Try first possible proposalId.

        if (proposalId_ != 0) return proposalId_;

        proposalId_ = _execute(callDatas_[0], firstPotentialVoteStart_ - 1); // Try second possible proposalId.

        if (proposalId_ != 0) return proposalId_;

        revert ProposalCannotBeExecuted();
    }

    // TODO: If PowerToken has "future active checkpoints", then this would not be needed.
    function markEpochActive() external {
        if (_numberOfProposals[PureEpochs.currentEpoch()] == 0) revert EpochHasNoProposals();

        IPowerToken(_voteToken).markEpochActive();
    }

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external returns (uint256 proposalId_) {
        if (targets_.length != 1) revert InvalidTargetsLength();
        if (targets_[0] != address(this)) revert InvalidTarget();

        if (values_.length != 1) revert InvalidValuesLength();
        if (values_[0] != 0) revert InvalidValue();

        if (callDatas_.length != 1) revert InvalidCallDatasLength();

        _revertIfInvalidCalldata(callDatas_[0]);

        uint256 voteStart_ = PureEpochs.currentEpoch();
        uint256 voteEnd_ = voteStart_;

        proposalId_ = _hashProposal(callDatas_[0], voteStart_);

        if (_proposals[proposalId_].voteStart != 0) revert ProposalExists();

        _numberOfProposals[voteStart_] += 1;

        address cashToken_ = _cashToken;
        uint256 proposalFee_ = _proposalFee;

        _proposalFees[proposalId_] = ProposalFeeInfo({ cashToken: cashToken_, fee: proposalFee_ });

        ERC20Helper.transferFrom(cashToken_, msg.sender, address(this), proposalFee_);

        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: false,
            proposer: msg.sender,
            noWeight: 0,
            yesWeight: 0
        });

        emit ProposalCreated(
            proposalId_,
            msg.sender,
            targets_,
            values_,
            new string[](targets_.length), // TODO: `string[] signatures` is silly.
            callDatas_,
            voteStart_,
            voteEnd_,
            description_
        );
    }

    function sendProposalFeeToVault(uint256 proposalId_) external {
        ProposalState state_ = state(proposalId_);

        // Must be expired or defeated to have the fee sent to the vault
        if (state_ != ProposalState.Expired && state_ != ProposalState.Defeated) revert FeeNotDestinedForVault(state_);

        uint256 proposalFee_ = _proposalFees[proposalId_].fee;
        address cashToken_ = _proposalFees[proposalId_].cashToken;

        delete _proposalFees[proposalId_];

        emit ProposalFeeSentToVault(proposalId_, cashToken_, proposalFee_);

        // NOTE: Not calling `distribute` on vault since:
        //         - anyone can do it, anytime
        //         - `DualGovernor` should not need to know how the vault works
        ERC20Helper.transfer(cashToken_, _vault, proposalFee_);
    }

    function setCashToken(address newCashToken_, uint256 newProposalFee_) external onlyZeroGovernor {
        _setCashToken(newCashToken_);
        _setProposalFee(newProposalFee_);
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
            uint16 voteStart_,
            uint16 voteEnd_,
            bool executed_,
            ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_
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
    }

    function getVotes(address account_, uint256 timepoint_) public view returns (uint256 weight_) {
        return IEpochBasedVoteToken(_voteToken).getPastVotes(account_, timepoint_);
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

    function hasVoted(uint256 proposalId_, address account_) external view returns (bool hasVoted_) {
        return _hasVoted[proposalId_][account_];
    }

    function hasVotedOnAllProposals(address voter_, uint256 epoch_) external view returns (bool hasVoted_) {
        return _numberOfProposalsVotedOn[epoch_][voter_] == _numberOfProposals[epoch_];
    }

    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256 reward_) {
        return _maxTotalZeroRewardPerActiveEpoch;
    }

    function name() external view returns (string memory name_) {
        return _name;
    }

    function numberOfProposalsAt(uint256 epoch_) external view returns (uint256 count_) {
        return _numberOfProposals[epoch_];
    }

    function numberOfProposalsVotedOnAt(uint256 epoch_, address voter_) external view returns (uint256 count_) {
        return _numberOfProposalsVotedOn[epoch_][voter_];
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

    function quorum(uint256) external pure returns (uint256 quorum_) {
        return 0;
    }

    function registrar() external view returns (address registrar_) {
        return _registrar;
    }

    function state(uint256 proposalId_) public view returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 currentEpoch_ = PureEpochs.currentEpoch();
        uint256 voteStart_ = proposal_.voteStart;
        uint256 voteEnd_ = proposal_.voteEnd;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        if (currentEpoch_ <= voteEnd_) return ProposalState.Active;

        if (proposal_.yesWeight <= proposal_.noWeight) return ProposalState.Defeated;

        return (currentEpoch_ > voteEnd_ + 2) ? ProposalState.Succeeded : ProposalState.Expired;
    }

    function vault() external view returns (address vault_) {
        return _vault;
    }

    function voteToken() external view returns (address voteToken_) {
        return _voteToken;
    }

    function votingDelay() public view returns (uint256 votingDelay_) {
        return _isVotingEpoch(PureEpochs.currentEpoch()) ? 2 : 1;
    }

    function votingPeriod() external pure returns (uint256 votingPeriod_) {
        return 1;
    }

    function zeroToken() external view returns (address zeroToken_) {
        return _zeroToken;
    }

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    function addAndRemoveFromList(bytes32 list_, address accountToAdd_, address accountToRemove_) external onlySelf {
        _addToList(list_, accountToAdd_);
        _removeFromList(list_, accountToRemove_);
    }

    function removeFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    function setProposalFee(uint256 newProposalFee_) external onlySelfOrEmergencyGovernor {
        _setProposalFee(newProposalFee_);
    }

    function updateConfig(bytes32 key_, bytes32 value_) external onlySelf {
        IRegistrar(_registrar).updateConfig(key_, value_);
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

        weight_ = getVotes(voter_, snapshot_);

        if (VoteType(support_) == VoteType.No) {
            proposal_.noWeight += weight_;
        } else {
            proposal_.yesWeight += weight_;
        }

        emit VoteCast(voter_, proposalId_, support_, weight_, "");

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 numberOfProposalsVotedOn_ = ++_numberOfProposalsVotedOn[currentEpoch_][voter_];

        if (numberOfProposalsVotedOn_ != _numberOfProposals[currentEpoch_]) return weight_;

        IPowerToken(_voteToken).markParticipation(voter_);

        IZeroToken(_zeroToken).mint(voter_, (_maxTotalZeroRewardPerActiveEpoch * weight_) / _getTotalSupply(snapshot_));
    }

    function _execute(bytes memory callData_, uint256 voteStart_) internal returns (uint256 proposalId_) {
        proposalId_ = _hashProposal(callData_, voteStart_);

        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.voteStart != voteStart_) return 0;

        if (state(proposalId_) != ProposalState.Succeeded) return 0;

        proposal_.executed = true;

        emit ProposalExecuted(proposalId_);

        (bool success_, bytes memory data_) = address(this).call(callData_);

        if (!success_) revert ExecutionFailed(data_);

        uint256 proposalFee_ = _proposalFees[proposalId_].fee;
        address cashToken_ = _proposalFees[proposalId_].cashToken;

        delete _proposalFees[proposalId_];

        ERC20Helper.transfer(cashToken_, proposal_.proposer, proposalFee_);
    }

    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(_registrar).removeFromList(list_, account_);
    }

    function _setCashToken(address newCashToken_) internal {
        if (newCashToken_ == address(0)) revert InvalidCashTokenAddress();

        emit CashTokenSet(_cashToken = newCashToken_);
    }

    function _setProposalFee(uint256 newProposalFee_) internal {
        emit ProposalFeeSet(_proposalFee = newProposalFee_);
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

    function _getSigner(bytes32 digest_, uint8 v_, bytes32 r_, bytes32 s_) internal view returns (address signer_) {
        signer_ = _getSigner(digest_, type(uint256).max, v_, r_, s_); // NOTE: No expiration.
    }

    function _getTotalSupply(uint256 timepoint_) internal view returns (uint256 totalSupply_) {
        return IEpochBasedVoteToken(_voteToken).totalSupplyAt(timepoint_);
    }

    function _hashProposal(bytes memory callData_) internal view returns (uint256 proposalId_) {
        return _hashProposal(callData_, PureEpochs.currentEpoch() + votingDelay());
    }

    function _hashProposal(bytes memory callData_, uint256 voteStart_) internal pure returns (uint256 proposalId_) {
        return uint256(keccak256(abi.encode(callData_, voteStart_)));
    }

    // TODO: Consider inlining this in the only place it's used.
    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1;
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure {
        bytes4 func_ = bytes4(callData_);

        if (
            func_ != this.addToList.selector &&
            func_ != this.addAndRemoveFromList.selector &&
            func_ != this.removeFromList.selector &&
            func_ != this.setProposalFee.selector &&
            func_ != this.updateConfig.selector
        ) revert InvalidCallData();
    }

    function _revertIfNotSelf() internal view {
        if (msg.sender != address(this)) revert NotSelf();
    }

    function _revertIfNotSelfOrEmergencyGovernor() internal view {
        if (msg.sender != address(this) && msg.sender != _emergencyGovernor) revert NotSelfOrEmergencyGovernor();
    }

    function _revertIfNotZeroGovernor() internal view {
        if (msg.sender != _zeroGovernor) revert NotZeroGovernor();
    }
}
