// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IGovernor } from "./abstract/interfaces/IGovernor.sol";

import { BatchGovernor } from "./abstract/BatchGovernor.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

/// @title An instance of a BatchGovernor with a unique and limited set of possible proposals with proposal fees.
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

    mapping(uint256 epoch => uint256 count) public numberOfProposalsAt;

    mapping(address voter => mapping(uint256 epoch => uint256 count)) public numberOfProposalsVotedOnAt;

    modifier onlyZeroGovernor() {
        _revertIfNotZeroGovernor();
        _;
    }

    modifier onlySelfOrEmergencyGovernor() {
        _revertIfNotSelfOrEmergencyGovernor();
        _;
    }

    constructor(
        address voteToken_,
        address emergencyGovernor_,
        address zeroGovernor_,
        address cashToken_,
        address registrar_,
        address vault_,
        address zeroToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) BatchGovernor("StandardGovernor", voteToken_) {
        if ((emergencyGovernor = emergencyGovernor_) == address(0)) revert InvalidEmergencyGovernorAddress();
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();

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
        uint256 currentEpoch_ = clock();

        if (currentEpoch_ == 0) revert InvalidEpoch();

        // Proposals have voteStart=N and voteEnd=N, and can be executed only during epochs N+1 and N+2.
        uint256 latestPossibleVoteStart_ = currentEpoch_ - 1;

        proposalId_ = _tryExecute(
            callDatas_[0],
            latestPossibleVoteStart_,
            latestPossibleVoteStart_ > 0 ? latestPossibleVoteStart_ - 1 : 0 // earliestPossibleVoteStart
        );

        ProposalFeeInfo storage proposalFeeInfo_ = _proposalFees[proposalId_];
        uint256 proposalFee_ = proposalFeeInfo_.fee;
        address cashToken_ = proposalFeeInfo_.cashToken;

        if (proposalFee_ > 0) {
            delete _proposalFees[proposalId_];
            _transfer(cashToken_, _proposals[proposalId_].proposer, proposalFee_);
        }
    }

    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external override returns (uint256 proposalId_) {
        uint256 voteStart_;

        (proposalId_, voteStart_) = _propose(targets_, values_, callDatas_, description_);

        uint256 proposalFee_ = proposalFee;

        if (proposalFee_ == 0) return proposalId_;

        address cashToken_ = cashToken;

        _proposalFees[proposalId_] = ProposalFeeInfo({ cashToken: cashToken_, fee: proposalFee_ });

        // If this is the first proposal for the `voteStart_` epoch, inflate its target total supply of `PowerToken`.
        if (++numberOfProposalsAt[voteStart_] == 1) {
            IPowerToken(voteToken).markNextVotingEpochAsActive();
        }

        if (!ERC20Helper.transferFrom(cashToken_, msg.sender, address(this), proposalFee_)) revert TransferFromFailed();
    }

    function sendProposalFeeToVault(uint256 proposalId_) external {
        ProposalState state_ = state(proposalId_);

        // Must be expired or defeated to have the fee sent to the vault
        if (state_ != ProposalState.Expired && state_ != ProposalState.Defeated) revert FeeNotDestinedForVault(state_);

        uint256 proposalFee_ = _proposalFees[proposalId_].fee;

        if (proposalFee_ == 0) revert NoFeeToSend();

        address cashToken_ = _proposalFees[proposalId_].cashToken;

        delete _proposalFees[proposalId_];

        emit ProposalFeeSentToVault(proposalId_, cashToken_, proposalFee_);

        // NOTE: Not calling `distribute` on vault since anyone can do it, anytime, and this contract should not need to
        //       know how the vault works
        _transfer(cashToken_, vault, proposalFee_);
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
            uint48 voteStart_,
            uint48 voteEnd_,
            bool executed_,
            ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        voteStart_ = proposal_.voteStart;
        voteEnd_ = _getVoteEnd(voteStart_);
        executed_ = proposal_.executed;
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
    }

    function hasVotedOnAllProposals(address voter_, uint256 epoch_) external view returns (bool hasVoted_) {
        return numberOfProposalsVotedOnAt[voter_][epoch_] == numberOfProposalsAt[epoch_];
    }

    function quorum() external pure returns (uint256 quorum_) {
        return 0;
    }

    function quorum(uint256) external pure returns (uint256 quorum_) {
        return 0;
    }

    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState state_) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint256 currentEpoch_ = clock();
        uint256 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        uint256 voteEnd_ = _getVoteEnd(voteStart_);

        if (currentEpoch_ <= voteEnd_) return ProposalState.Active;

        if (proposal_.yesWeight <= proposal_.noWeight) return ProposalState.Defeated;

        return (currentEpoch_ <= voteEnd_ + 2) ? ProposalState.Succeeded : ProposalState.Expired;
    }

    function votingDelay() public view override(BatchGovernor, IGovernor) returns (uint256 votingDelay_) {
        return _isVotingEpoch(clock()) ? 2 : 1;
    }

    function votingPeriod() public pure override(BatchGovernor, IGovernor) returns (uint256 votingPeriod_) {
        return 0;
    }

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    function removeFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    function removeFromAndAddToList(bytes32 list_, address accountToRemove_, address accountToAdd_) external onlySelf {
        _removeFromList(list_, accountToRemove_);
        _addToList(list_, accountToAdd_);
    }

    function setKey(bytes32 key_, bytes32 value_) external onlySelf {
        IRegistrar(registrar).setKey(key_, value_);
    }

    function setProposalFee(uint256 newProposalFee_) external onlySelfOrEmergencyGovernor {
        _setProposalFee(newProposalFee_);
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

        uint256 currentEpoch_ = clock();
        uint256 numberOfProposalsVotedOn_ = ++numberOfProposalsVotedOnAt[voter_][currentEpoch_];

        // NOTE: Will only get beyond this statement once per epoch as there is no way to vote on more proposals than
        //       exist in this epoch.
        if (numberOfProposalsVotedOn_ != numberOfProposalsAt[currentEpoch_]) return (weight_, snapshot_);

        emit HasVotedOnAllProposals(voter_, currentEpoch_);

        IPowerToken(voteToken).markParticipation(voter_);
        IZeroToken(zeroToken).mint(voter_, (maxTotalZeroRewardPerActiveEpoch * weight_) / _getTotalSupply(snapshot_));
    }

    function _createProposal(uint256 proposalId_, uint256 voteStart_) internal override {
        _proposals[proposalId_] = Proposal({
            voteStart: uint48(voteStart_),
            executed: false,
            proposer: msg.sender,
            thresholdRatio: 0,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
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

    function _transfer(address token_, address to_, uint256 amount_) internal {
        if (!ERC20Helper.transfer(token_, to_, amount_)) revert TransferFailed();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    // TODO: Consider inlining this in the only place it's used.
    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1; // Voting epochs are odd numbered.
    }

    /// @dev All proposals target this contract itself, and must call one of the listed functions to be valid.
    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {
        bytes4 func_ = bytes4(callData_);

        if (
            func_ != this.addToList.selector &&
            func_ != this.removeFromList.selector &&
            func_ != this.removeFromAndAddToList.selector &&
            func_ != this.setKey.selector &&
            func_ != this.setProposalFee.selector
        ) revert InvalidCallData();
    }

    function _revertIfNotSelfOrEmergencyGovernor() internal view {
        if (msg.sender != address(this) && msg.sender != emergencyGovernor) revert NotSelfOrEmergencyGovernor();
    }

    function _revertIfNotZeroGovernor() internal view {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
    }
}
