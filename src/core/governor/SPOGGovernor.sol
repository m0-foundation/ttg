// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {DualGovernorVotesQuorumFraction} from "src/core/governor/DualGovernorVotesQuorumFraction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SPOG Governor Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin.
contract SPOGGovernor is ISPOGGovernor, DualGovernorVotesQuorumFraction {
    using SafeERC20 for IERC20;

    // @note minimum voting delay in blocks
    uint256 public constant MINIMUM_VOTING_DELAY = 1;

    address public spogAddress;
    uint256 private immutable _votingPeriod;

    uint256 private _votingPeriodChangedBlockNumber;
    uint256 private _votingPeriodChangedEpoch;

    // @note voting with no delay is required for certain proposals
    bool private _emergencyVotingIsOn;

    // private mappings
    mapping(uint256 => ProposalVote) private _proposalVotes;
    mapping(uint256 => ProposalType) private _proposalTypes;

    // public mappings
    mapping(uint256 => bool) public emergencyProposals;
    // epoch => proposalCount
    mapping(uint256 => uint256) public epochProposalsCount;
    // address => epoch => number of proposals voted on
    mapping(address => mapping(uint256 => uint256)) public accountEpochNumProposalsVotedOn;
    // epoch => cumulative epoch vote weight casted
    mapping(uint256 => uint256) public epochSumOfVoteWeight;

    uint256 public quorumNumerator;

    modifier onlySPOG() {
        if (msg.sender != spogAddress) revert CallerIsNotSPOG(msg.sender);

        _;
    }

    /// @param voteQuorum_ The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param valueQuorum_ The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param votingPeriod_ The duration of a voting epochs for governor and auctions in blocks
    constructor(
        string memory name_,
        address vote_,
        address value_,
        uint256 voteQuorum_,
        uint256 valueQuorum_,
        uint256 votingPeriod_
    ) DualGovernorVotesQuorumFraction(name_, vote_, value_, voteQuorum_, valueQuorum_) {
        // TODO: sanity checks
        _votingPeriod = votingPeriod_;
        _votingPeriodChangedBlockNumber = block.number;
    }

    function initSPOGAddress(address _spogAddress) external override {
        if (spogAddress != address(0)) {
            revert SPOGAddressAlreadySet(spogAddress);
        }

        vote.initSPOGAddress(_spogAddress);
        value.initSPOGAddress(_spogAddress);
        spogAddress = _spogAddress;
    }

    /// @dev get current epoch number - 1, 2, 3, .. etc
    function currentEpoch() public view override returns (uint256) {
        uint256 blocksSinceVotingPeriodChange = block.number - _votingPeriodChangedBlockNumber;

        return _votingPeriodChangedEpoch + blocksSinceVotingPeriodChange / _votingPeriod;
    }

    /// @dev get `block.number` of the start of the next epoch
    function startOfNextEpoch() public view override returns (uint256) {
        uint256 nextEpoch = currentEpoch() + 1;

        return startOfEpoch(nextEpoch);
    }

    /// @dev get `block.number` of the start of the given epoch
    /// we can correctly calculate start of epochs only for current and future epochs
    /// it happens because epoch voting time can be changed more than once
    function startOfEpoch(uint256 epoch) public view override returns (uint256) {
        if (epoch < currentEpoch()) revert EpochInThePast(epoch, currentEpoch());
        uint256 epochsSinceVotingPeriodChange = epoch - _votingPeriodChangedEpoch;

        return _votingPeriodChangedBlockNumber + epochsSinceVotingPeriodChange * _votingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    function _registerEmergencyProposal(uint256 proposalId) internal virtual {
        emergencyProposals[proposalId] = true;
    }

    function _turnOnEmergencyVoting() internal virtual {
        _emergencyVotingIsOn = true;
    }

    function _turnOffEmergencyVoting() internal virtual {
        _emergencyVotingIsOn = false;
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
        // update epochProposalsCount. Proposals are voted on in the next epoch
        epochProposalsCount[currentEpoch() + 1]++;

        // allow only 1 SPOG change with no value per proposal
        if (targets.length != 1 || values[0] != 0) {
            revert InvalidProposal();
        }

        if (targets[0] != address(this) && targets[0] != spogAddress) {
            revert InvalidProposal();
        }

        bytes4 executableFuncSelector = bytes4(calldatas[0]);
        if (ISPOG(spogAddress).isGovernedMethod(executableFuncSelector)) {
            revert NotGovernedMethod(executableFuncSelector);
        }

        // _payFee(executableFuncSelector);

        // // Inflate Vote and Value token supply unless method is reset or emergencyRemove
        // if (executableFuncSelector != ISPOG.reset.selector && executableFuncSelector != ISPOG.emergency.selector)
        // {
        //     _inflateRewardTokens();
        // }

        // Only $VALUE governance proposals
        if (executableFuncSelector == ISPOG.reset.selector) {
            _turnOnEmergencyVoting();
            uint256 proposalId = super.propose(targets, values, calldatas, description);
            _turnOffEmergencyVoting();

            _proposalTypes[proposalId] = ProposalType.Value;

            // emit NewValueQuorumProposal(proposalId);
            return proposalId;
        }

        // TODO: add proposal to change quorum numerators as double proposal too

        // $VALUE and $VOTE governance proposals
        // If we request to change config parameter, value governance should vote too
        if (executableFuncSelector == ISPOG.changeTaxRange.selector) {
            uint256 proposalId = super.propose(targets, values, calldatas, description);
            _proposalTypes[proposalId] = ProposalType.Double;
            // emit NewDoubleQuorumProposal(voteProposalId);
            return proposalId;
        }

        // Only $VOTE governance proposals

        if (executableFuncSelector == ISPOG.emergency.selector) {
            _turnOnEmergencyVoting();
            uint256 proposalId = super.propose(targets, values, calldatas, description);
            _turnOffEmergencyVoting();

            _proposalTypes[proposalId] = ProposalType.Vote;
            _registerEmergencyProposal(proposalId);

            // emit NewEmergencyProposal(proposalId);
            return proposalId;
        }

        uint256 proposalId = super.propose(targets, values, calldatas, description);
        _proposalTypes[proposalId] = ProposalType.Vote;
        // prevent proposing a list that can be changed before execution
        // if (executableFuncSelector == this.addNewList.selector) {
        //     address listParams = _extractAddressTypeParamsFromCalldata(calldatas[0]);
        //     if (IList(listParams).admin() != address(this)) {
        //         revert ListAdminIsNotSPOG();
        //     }
        // }

        // emit NewVoteQuorumProposal(proposalId);
        return proposalId;
    }

    /// @notice override to count user activity in epochs
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        require(state(proposalId) == ProposalState.Active, "SPOGGovernor: vote not currently active");

        ProposalType proposalType = _proposalTypes[proposalId];
        uint256 snapshot = proposalSnapshot(proposalId);
        uint256 voteWeight = (proposalType == ProposalType.Vote || proposalType == ProposalType.Double)
            ? _getVoteVotes(account, snapshot, params)
            : 0;
        uint256 valueWeight = (proposalType == ProposalType.Value || proposalType == ProposalType.Double)
            ? _getValueVotes(account, snapshot, params)
            : 0;

        _countVote(proposalId, account, support, voteWeight, valueWeight, params);

        if (voteWeight > 0) {
            _updateAccountEpochVotes(voteWeight);
        }

        // TODO: adjust weight we need to return ?
        if (params.length == 0) {
            emit VoteCast(account, proposalId, support, voteWeight, reason);
        } else {
            emit VoteCastWithParams(account, proposalId, support, voteWeight, reason, params);
        }

        return voteWeight;
    }

    /// @dev update number of proposals account voted for and cumulative vote weight casted in epoch
    function _updateAccountEpochVotes(uint256 weight) internal virtual {
        uint256 epoch = currentEpoch();

        // update number of proposals account voted for in current epoch
        accountEpochNumProposalsVotedOn[msg.sender][epoch]++;

        // update cumulative vote weight for epoch if user voted in all proposals
        if (accountEpochNumProposalsVotedOn[msg.sender][epoch] == epochProposalsCount[epoch]) {
            epochSumOfVoteWeight[epoch] += weight;
        }
    }

    /**
     * @dev Overridden version of the {Governor-state} function with added support for emergency proposals.
     */
    function state(uint256 proposalId) public view override returns (ProposalState) {
        ProposalState status = super.state(proposalId);

        // If emergency proposal is `Active` and quorum is reached, change status to `Succeeded` even if deadline is not passed yet.
        // Use only `_quorumReached` for this check, `_voteSucceeded` is not needed as it is the same.
        if (emergencyProposals[proposalId] && status == ProposalState.Active && _quorumReached(proposalId)) {
            return ProposalState.Succeeded;
        }

        return status;
    }

    function votingDelay() public view override returns (uint256) {
        return _emergencyVotingIsOn ? MINIMUM_VOTING_DELAY : startOfNextEpoch() - block.number;
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            COUNTING MODULE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev See {GovernorBase-COUNTING_MODE}.
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure override returns (string memory) {
        return "support=alpha&quorum=alpha";
    }

    /// @dev See {GovernorBase-hasVoted}.
    function hasVoted(uint256 proposalId, address account) public view override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /// @dev Accessor to the internal vote counts.
    function proposalVoteVotes(uint256 proposalId) public view override returns (uint256 noVotes, uint256 yesVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.voteNoVotes, proposalVote.voteYesVotes);
    }

    /// @dev Accessor to the internal vote counts.
    function proposalValueVotes(uint256 proposalId) public view override returns (uint256 noVotes, uint256 yesVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.valueNoVotes, proposalVote.valueYesVotes);
    }

    /// @dev See {Governor-_quorumReached}.
    function _quorumReached(uint256 proposalId) internal view override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        ProposalType proposalType = _proposalTypes[proposalId];
        uint256 snapshot = proposalSnapshot(proposalId);
        uint256 voteQuorum_ = voteQuorum(snapshot);
        uint256 valueQuorum_ = valueQuorum(snapshot);

        // TODO: fix checks with 0 quorum
        if (proposalType == ProposalType.Vote) {
            return voteQuorum_ <= proposalVote.voteYesVotes && voteQuorum_ > 0;
        }
        if (proposalType == ProposalType.Value) {
            return valueQuorum_ <= proposalVote.valueYesVotes && valueQuorum_ > 0;
        }
        if (proposalType == ProposalType.Double) {
            return voteQuorum_ <= proposalVote.voteYesVotes && voteQuorum_ > 0
                && valueQuorum_ <= proposalVote.valueYesVotes && valueQuorum_ > 0;
        }

        revert InvalidProposal();
    }

    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(uint256 proposalId) internal view override returns (bool) {
        return _quorumReached(proposalId);
    }

    function _getVoteVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        returns (uint256)
    {
        return vote.getPastVotes(account, timepoint);
    }

    function _getValueVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        returns (uint256)
    {
        return value.getPastVotes(account, timepoint);
    }

    function _getVotes(address, /*account*/ uint256, /*timepoint*/ bytes memory /*params*/ )
        internal
        view
        virtual
        override
        returns (uint256)
    {
        revert("Not implemented");
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 voteVotes,
        uint256 valueVotes,
        bytes memory
    ) internal virtual {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalVote.hasVoted[account]) {
            revert AlreadyVoted(proposalId, account);
        }
        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.No)) {
            proposalVote.voteNoVotes += voteVotes;
            proposalVote.valueNoVotes += valueVotes;
        } else {
            proposalVote.voteYesVotes += voteVotes;
            proposalVote.valueYesVotes += valueVotes;
        }
    }

    function _countVote(uint256, address, uint8, uint256, bytes memory) internal virtual override {
        revert("Not implemented");
    }

    /// @notice pay tax from the caller to the SPOG
    /// @param funcSelector The executable function selector
    function _payFee(bytes4 funcSelector) private {
        (uint256 fee, address cash) = ISPOG(spogAddress).getFee(funcSelector);
        IValueVault vault = ISPOG(spogAddress).valueVault();

        // transfer the amount from the caller to the SPOG
        IERC20(cash).safeTransferFrom(msg.sender, address(this), fee);
        // approve amount to be sent to the vault
        IERC20(cash).approve(address(vault), fee);

        // deposit the amount to the vault
        vault.depositRewards(currentEpoch(), cash, fee);
    }

    /// @notice inflate Vote and Value token supplies
    /// @dev Called once per epoch when the first reward-accruing proposal is submitted ( except reset and emergencyRemove)
    // function _inflateRewardTokens() private {
    //     uint256 nextEpoch = governor.currentEpoch() + 1;

    //     // Epoch reward tokens already minted, silently return
    //     if (epochRewardsMinted[nextEpoch]) return;

    //     epochRewardsMinted[nextEpoch] = true;

    //     // Mint and deposit Vote and Value rewards to vault
    //     _mintRewardsAndDepositToVault(nextEpoch, governor.vote(), voteTokenInflationPerEpoch());
    //     _mintRewardsAndDepositToVault(nextEpoch, governor.value(), valueTokenInflationPerEpoch());
    // }

    // /// @notice mint reward token into the vault
    // /// @param epoch The epoch for which rewards become claimable
    // /// @param token The reward token, only vote or value tokens
    // /// @param amount The amount to mint and deposit into the vault
    // function _mintRewardsAndDepositToVault(uint256 epoch, ISPOGVotes token, uint256 amount) private {
    //     token.mint(address(this), amount);
    //     token.approve(address(voteVault), amount);
    //     voteVault.depositRewards(epoch, address(token), amount);
    // }

    fallback() external {
        revert("SPOGGovernor: non-existent function");
    }
}
