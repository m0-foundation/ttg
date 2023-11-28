// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IGovernor } from "./abstract/interfaces/IGovernor.sol";

import { BatchGovernor } from "./abstract/BatchGovernor.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

// TODO: Determine standard way to inform externals about which token can vote.

// TODO: Implement `QuorumNumeratorUpdated` (`quorumNumerator`, `quorumDenominator`) in the DualGovernor contract.
// TODO: Emit an event in the Governor or Power Token when a voter has voted on all standard proposals in an epoch.
// TODO: Consider non-standard simplified versions of governor functions.

contract StandardGovernor is IStandardGovernor, BatchGovernor {
    struct ProposalFeeInfo {
        address cashToken;
        uint256 fee;
    }

    address public immutable emergencyGovernor;
    address public immutable registrar;
    address public immutable vault;
    address public immutable zeroGovernor;
    address public immutable zeroToken;

    uint256 public immutable maxTotalZeroRewardPerActiveEpoch;

    address public cashToken;

    uint256 public proposalFee;

    mapping(uint256 proposalId => ProposalFeeInfo proposalFee) internal _proposalFees;

    mapping(uint256 epoch => uint256 count) internal _numberOfProposals;

    mapping(uint256 epoch => mapping(address voter => uint256 count)) internal _numberOfProposalsVotedOn;

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
    ) BatchGovernor("StandardGovernor", voteToken_) {
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((emergencyGovernor = emergencyGovernor_) == address(0)) revert InvalidEmergencyGovernorAddress();
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();

        _setCashToken(cashToken_);
        _setProposalFee(proposalFee_);

        maxTotalZeroRewardPerActiveEpoch = maxTotalZeroRewardPerActiveEpoch_;
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
        if (msg.value != 0) revert InvalidValue();

        // Proposals have voteStart=N and voteEnd=N, and can be executed only during epochs N+1 and N+2.
        uint256 firstPotentialVoteStart_ = PureEpochs.currentEpoch() - 1;

        proposalId_ = _tryExecute(callDatas_[0], firstPotentialVoteStart_, firstPotentialVoteStart_ - 1);
    }

    // TODO: If PowerToken has "future active checkpoints", then this would not be needed.
    function markEpochActive() external {
        if (_numberOfProposals[PureEpochs.currentEpoch()] == 0) revert EpochHasNoProposals();

        IPowerToken(voteToken).markEpochActive();
    }

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external override returns (uint256 proposalId_) {
        uint256 voteStart_;

        (proposalId_, voteStart_) = _propose(targets_, values_, callDatas_, description_);

        _numberOfProposals[voteStart_] += 1;

        address cashToken_ = cashToken;
        uint256 proposalFee_ = proposalFee;

        _proposalFees[proposalId_] = ProposalFeeInfo({ cashToken: cashToken_, fee: proposalFee_ });

        ERC20Helper.transferFrom(cashToken_, msg.sender, address(this), proposalFee_);
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
        ERC20Helper.transfer(cashToken_, vault, proposalFee_);
    }

    function setCashToken(address newCashToken_, uint256 newProposalFee_) external onlyZeroGovernor {
        _setCashToken(newCashToken_);
        _setProposalFee(newProposalFee_);
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

    function hasVotedOnAllProposals(address voter_, uint256 epoch_) external view returns (bool hasVoted_) {
        return _numberOfProposalsVotedOn[epoch_][voter_] == _numberOfProposals[epoch_];
    }

    function numberOfProposalsAt(uint256 epoch_) external view returns (uint256 count_) {
        return _numberOfProposals[epoch_];
    }

    function numberOfProposalsVotedOnAt(uint256 epoch_, address voter_) external view returns (uint256 count_) {
        return _numberOfProposalsVotedOn[epoch_][voter_];
    }

    function quorum(uint256) external pure returns (uint256 quorum_) {
        return 0;
    }

    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 currentEpoch_ = PureEpochs.currentEpoch();
        uint256 voteStart_ = proposal_.voteStart;
        uint256 voteEnd_ = proposal_.voteEnd;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        if (currentEpoch_ <= voteEnd_) return ProposalState.Active;

        if (proposal_.yesWeight <= proposal_.noWeight) return ProposalState.Defeated;

        return (currentEpoch_ <= voteEnd_ + 2) ? ProposalState.Succeeded : ProposalState.Expired;
    }

    function votingDelay() public view override(BatchGovernor, IGovernor) returns (uint256 votingDelay_) {
        return _isVotingEpoch(PureEpochs.currentEpoch()) ? 2 : 1;
    }

    function votingPeriod() public pure returns (uint256 votingPeriod_) {
        return 0;
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
        IRegistrar(registrar).updateConfig(key_, value_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _addToList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).addToList(list_, account_);
    }

    function _castVote(
        address voter_,
        uint256 proposalId_,
        uint8 support_
    ) internal override returns (uint256 weight_, uint256 snapshot_) {
        (weight_, snapshot_) = super._castVote(voter_, proposalId_, support_);

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 numberOfProposalsVotedOn_ = ++_numberOfProposalsVotedOn[currentEpoch_][voter_];

        if (numberOfProposalsVotedOn_ != _numberOfProposals[currentEpoch_]) return (weight_, snapshot_);

        IPowerToken(voteToken).markParticipation(voter_);

        IZeroToken(zeroToken).mint(voter_, (maxTotalZeroRewardPerActiveEpoch * weight_) / _getTotalSupply(snapshot_));
    }

    function _createProposal(uint256 proposalId_, uint256 voteStart_) internal override returns (uint256 voteEnd_) {
        voteEnd_ = voteStart_;

        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: false,
            proposer: msg.sender,
            thresholdRatio: 0,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
    }

    function _execute(bytes memory callData_, uint256 voteStart_) internal override returns (uint256 proposalId_) {
        proposalId_ = super._execute(callData_, voteStart_);

        uint256 proposalFee_ = _proposalFees[proposalId_].fee;
        address cashToken_ = _proposalFees[proposalId_].cashToken;

        delete _proposalFees[proposalId_];

        ERC20Helper.transfer(cashToken_, _proposals[proposalId_].proposer, proposalFee_);
    }

    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).removeFromList(list_, account_);
    }

    function _setCashToken(address newCashToken_) internal {
        if (newCashToken_ == address(0)) revert InvalidCashTokenAddress();

        emit CashTokenSet(cashToken = newCashToken_);
    }

    function _setProposalFee(uint256 newProposalFee_) internal {
        emit ProposalFeeSet(proposalFee = newProposalFee_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    // TODO: Consider inlining this in the only place it's used.
    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1;
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {
        bytes4 func_ = bytes4(callData_);

        if (
            func_ != this.addToList.selector &&
            func_ != this.addAndRemoveFromList.selector &&
            func_ != this.removeFromList.selector &&
            func_ != this.setProposalFee.selector &&
            func_ != this.updateConfig.selector
        ) revert InvalidCallData();
    }

    function _revertIfNotSelfOrEmergencyGovernor() internal view {
        if (msg.sender != address(this) && msg.sender != emergencyGovernor) revert NotSelfOrEmergencyGovernor();
    }

    function _revertIfNotZeroGovernor() internal view {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
    }
}
