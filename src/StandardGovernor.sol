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

    /// @inheritdoc IStandardGovernor
    address public immutable emergencyGovernor;

    /// @inheritdoc IStandardGovernor
    address public immutable registrar;

    /// @inheritdoc IStandardGovernor
    address public immutable vault;

    /// @inheritdoc IStandardGovernor
    address public immutable zeroGovernor;

    /// @inheritdoc IStandardGovernor
    address public immutable zeroToken;

    /// @inheritdoc IStandardGovernor
    uint256 public immutable maxTotalZeroRewardPerActiveEpoch;

    /// @inheritdoc IStandardGovernor
    address public cashToken;

    /// @inheritdoc IStandardGovernor
    uint256 public proposalFee;

    /// @dev The proposal fee info per proposal ID.
    mapping(uint256 proposalId => ProposalFeeInfo proposalFee) internal _proposalFees;

    /// @dev The amount of proposals per epoch.
    mapping(uint256 epoch => uint256 count) public numberOfProposalsAt;

    /// @dev The amount of proposals a voter has voted on per epoch.
    mapping(address voter => mapping(uint256 epoch => uint256 count)) public numberOfProposalsVotedOnAt;

    /// @dev Revert if the caller is not the Zero Governor.
    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
        _;
    }

    /// @dev Revert if the caller is not the Standard Governor nor the Emergency Governor.
    modifier onlySelfOrEmergencyGovernor() {
        if (msg.sender != address(this) && msg.sender != emergencyGovernor) revert NotSelfOrEmergencyGovernor();
        _;
    }

    /**
     * @notice Constructs a new StandardGovernor contract.
     * @param  voteToken_                        The address of the Vote Token contract.
     * @param  emergencyGovernor_                The address of the Emergency Governor contract.
     * @param  zeroGovernor_                     The address of the Zero Governor contract.
     * @param  cashToken_                        The address of the Cash Token contract.
     * @param  registrar_                        The address of the Registrar contract.
     * @param  vault_                            The address of the Vault contract.
     * @param  zeroToken_                        The address of the Zero Token contract.
     * @param  proposalFee_                      The proposal fee.
     * @param  maxTotalZeroRewardPerActiveEpoch_ The maximum amount of zero tokens to reward per active epoch.
     */
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

    /// @inheritdoc IGovernor
    function execute(
        address[] memory,
        uint256[] memory,
        bytes[] memory callDatas_,
        bytes32
    ) external payable returns (uint256 proposalId_) {
        uint16 currentEpoch_ = _clock();

        if (currentEpoch_ == 0) revert InvalidEpoch();

        // Proposals have voteStart=N and voteEnd=N, and can be executed only during epoch N+1.
        uint16 latestPossibleVoteStart_ = currentEpoch_ - 1;

        proposalId_ = _tryExecute(callDatas_[0], latestPossibleVoteStart_, latestPossibleVoteStart_);

        ProposalFeeInfo storage proposalFeeInfo_ = _proposalFees[proposalId_];
        uint256 proposalFee_ = proposalFeeInfo_.fee;
        address cashToken_ = proposalFeeInfo_.cashToken;

        if (proposalFee_ > 0) {
            delete _proposalFees[proposalId_];
            _transfer(cashToken_, _proposals[proposalId_].proposer, proposalFee_);
        }
    }

    /// @inheritdoc IGovernor
    function propose(
        address[] memory targets_,
        uint256[] memory values_,
        bytes[] memory callDatas_,
        string memory description_
    ) external override returns (uint256 proposalId_) {
        uint256 voteStart_;

        (proposalId_, voteStart_) = _propose(targets_, values_, callDatas_, description_);

        // If this is the first proposal for the `voteStart_` epoch, inflate its target total supply of `PowerToken`.
        if (++numberOfProposalsAt[voteStart_] == 1) {
            IPowerToken(voteToken).markNextVotingEpochAsActive();
        }

        uint256 proposalFee_ = proposalFee;

        if (proposalFee_ == 0) return proposalId_;

        address cashToken_ = cashToken;

        _proposalFees[proposalId_] = ProposalFeeInfo({ cashToken: cashToken_, fee: proposalFee_ });

        if (!ERC20Helper.transferFrom(cashToken_, msg.sender, address(this), proposalFee_)) revert TransferFromFailed();
    }

    /// @inheritdoc IStandardGovernor
    function setCashToken(address newCashToken_, uint256 newProposalFee_) external onlyZeroGovernor {
        _setCashToken(newCashToken_);

        IPowerToken(voteToken).setNextCashToken(newCashToken_);

        _setProposalFee(newProposalFee_);
    }

    /// @inheritdoc IStandardGovernor
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

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    /// @inheritdoc IStandardGovernor
    function addToList(bytes32 list_, address account_) external onlySelf {
        _addToList(list_, account_);
    }

    /// @inheritdoc IStandardGovernor
    function removeFromList(bytes32 list_, address account_) external onlySelf {
        _removeFromList(list_, account_);
    }

    /// @inheritdoc IStandardGovernor
    function removeFromAndAddToList(bytes32 list_, address accountToRemove_, address accountToAdd_) external onlySelf {
        _removeFromList(list_, accountToRemove_);
        _addToList(list_, accountToAdd_);
    }

    /// @inheritdoc IStandardGovernor
    function setKey(bytes32 key_, bytes32 value_) external onlySelf {
        IRegistrar(registrar).setKey(key_, value_);
    }

    /// @inheritdoc IStandardGovernor
    function setProposalFee(uint256 newProposalFee_) external onlySelfOrEmergencyGovernor {
        _setProposalFee(newProposalFee_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    /// @inheritdoc IStandardGovernor
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
            address proposer_
        )
    {
        Proposal storage proposal_ = _proposals[proposalId_];

        voteStart_ = proposal_.voteStart;
        voteEnd_ = _getVoteEnd(proposal_.voteStart);
        state_ = state(proposalId_);
        noVotes_ = proposal_.noWeight;
        yesVotes_ = proposal_.yesWeight;
        proposer_ = proposal_.proposer;
    }

    /// @inheritdoc IStandardGovernor
    function hasVotedOnAllProposals(address voter_, uint256 epoch_) external view returns (bool) {
        return numberOfProposalsVotedOnAt[voter_][epoch_] == numberOfProposalsAt[epoch_];
    }

    /// @inheritdoc IGovernor
    function quorum() external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IGovernor
    function quorum(uint256) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc IGovernor
    function state(uint256 proposalId_) public view override(BatchGovernor, IGovernor) returns (ProposalState) {
        Proposal storage proposal_ = _proposals[proposalId_];

        if (proposal_.executed) return ProposalState.Executed;

        uint16 currentEpoch_ = _clock();
        uint16 voteStart_ = proposal_.voteStart;

        if (voteStart_ == 0) revert ProposalDoesNotExist();

        if (currentEpoch_ < voteStart_) return ProposalState.Pending;

        uint16 voteEnd_ = _getVoteEnd(voteStart_);

        if (currentEpoch_ <= voteEnd_) return ProposalState.Active;

        if (proposal_.yesWeight <= proposal_.noWeight) return ProposalState.Defeated;

        unchecked {
            return (currentEpoch_ <= voteEnd_ + 1) ? ProposalState.Succeeded : ProposalState.Expired;
        }
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @dev    Cast votes on several proposals for `voter_`.
     * @param  voter_       The address of the voter.
     * @param  proposalIds_ The unique identifiers of the proposals.
     * @param  support_     The type of support to cast for each proposal.
     * @return weight_      The number of votes the voter cast on each proposal.
     */
    function _castVotes(
        address voter_,
        uint256[] calldata proposalIds_,
        uint8[] calldata support_
    ) internal override returns (uint256 weight_) {
        // In this governor, since the votingPeriod is 0, the snapshot for all active proposals is the previous epoch.
        weight_ = getVotes(voter_, _clock() - 1);

        for (uint256 index_; index_ < proposalIds_.length; ++index_) {
            _castVote(voter_, weight_, proposalIds_[index_], support_[index_]);
        }
    }

    /**
     * @dev   Adds `account` to `list` at the Registrar.
     * @param list_    The key for some list.
     * @param account_ The address of some account to be added.
     */
    function _addToList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).addToList(list_, account_);
    }

    /**
     * @dev   Cast `weight_` votes on a proposal with id `proposalId_` for `voter_`.
     * @param voter_      The address of the voter.
     * @param weight_     The number of votes the voter is casting.
     * @param proposalId_ The unique identifier of the proposal.
     * @param support_    The type of support to cast for the proposal.
     */
    function _castVote(address voter_, uint256 weight_, uint256 proposalId_, uint8 support_) internal override {
        super._castVote(voter_, weight_, proposalId_, support_);

        uint16 currentEpoch_ = _clock();
        uint256 numberOfProposalsVotedOn_ = ++numberOfProposalsVotedOnAt[voter_][currentEpoch_];

        // NOTE: Will only get beyond this statement once per epoch as there is no way to vote on more proposals than
        //       exist in this epoch.
        if (numberOfProposalsVotedOn_ != numberOfProposalsAt[currentEpoch_]) return;

        emit HasVotedOnAllProposals(voter_, currentEpoch_);

        IPowerToken(voteToken).markParticipation(voter_);

        IZeroToken(zeroToken).mint(
            voter_,
            (maxTotalZeroRewardPerActiveEpoch * weight_) / _getTotalSupply(currentEpoch_ - 1)
        );
    }

    /**
     * @dev   Creates a new proposal with the given parameters.
     * @param proposalId_ The unique identifier of the proposal.
     * @param voteStart_  The epoch at which the proposal will start collecting votes.
     */
    function _createProposal(uint256 proposalId_, uint16 voteStart_) internal override {
        _proposals[proposalId_] = Proposal({
            voteStart: voteStart_,
            executed: false,
            proposer: msg.sender,
            thresholdRatio: 0,
            quorumRatio: 0,
            noWeight: 0,
            yesWeight: 0
        });
    }

    /**
     * @dev   Removes `account_` from `list_` at the Registrar.
     * @param list_    The key for some list.
     * @param account_ The address of some account to be removed.
     */
    function _removeFromList(bytes32 list_, address account_) internal {
        IRegistrar(registrar).removeFromList(list_, account_);
    }

    /**
     * @dev   Set cash token to `newCashToken_`.
     * @param newCashToken_ The address of the new cash token.
     */
    function _setCashToken(address newCashToken_) internal {
        if (newCashToken_ == address(0)) revert InvalidCashTokenAddress();

        emit CashTokenSet(cashToken = newCashToken_);
    }

    /**
     * @dev   Set proposal fee to `newProposalFee_`.
     * @param newProposalFee_ The new proposal fee.
     */
    function _setProposalFee(uint256 newProposalFee_) internal {
        emit ProposalFeeSet(proposalFee = newProposalFee_);
    }

    /**
     * @dev   Transfer `amount_` of `token_` to `to_`.
     * @param token_  The address of the token to transfer.
     * @param to_     The address of the recipient.
     * @param amount_ The amount of tokens to transfer.
     */
    function _transfer(address token_, address to_, uint256 amount_) internal {
        if (!ERC20Helper.transfer(token_, to_, amount_)) revert TransferFailed();
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    /**
     * @dev    Returns the number of clock values that must elapse before voting begins for a newly created proposal.
     * @return The voting delay.
     */
    function _votingDelay() internal view override returns (uint16) {
        return clock() % 2 == 1 ? 2 : 1; // Voting epochs are odd numbered
    }

    /**
     * @dev   All proposals target this contract itself, and must call one of the listed functions to be valid.
     * @param callData_ The call data to check.
     */
    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {
        bytes4 func_ = bytes4(callData_);
        uint256 length = callData_.length;

        if (
            !(func_ == this.addToList.selector && length == 68) &&
            !(func_ == this.removeFromList.selector && length == 68) &&
            !(func_ == this.removeFromAndAddToList.selector && length == 100) &&
            !(func_ == this.setKey.selector && length == 68) &&
            !(func_ == this.setProposalFee.selector && length == 36)
        ) revert InvalidCallData();
    }

    /**
     * @dev    Returns the number of clock values between the vote start and vote end.
     * @return The voting period.
     */
    function _votingPeriod() internal pure override returns (uint16) {
        return 0;
    }
}
