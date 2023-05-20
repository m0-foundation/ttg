// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {SPOGGovernorBase, ISPOGVotes, Governor, GovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

/// @title SPOG Governor Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin.
contract SPOGGovernor is SPOGGovernorBase {
    // @note minimum voting delay in blocks
    uint256 public constant MINIMUM_VOTING_DELAY = 1;

    ISPOGVotes public immutable vote;
    ISPOGVotes public immutable value;

    uint256 private _votingPeriod;
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

    constructor(
        ISPOGVotes vote_,
        ISPOGVotes value_,
        uint256 quorumNumerator,
        uint256 votingPeriod_,
        string memory name_
    ) SPOGGovernorBase(vote_, quorumNumerator, name_) {
        vote = vote_;
        value = value_;
        _votingPeriod = votingPeriod_;
        _votingPeriodChangedBlockNumber = block.number;
    }

    /// @inheritdoc SPOGGovernorBase
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
    /// it happens because epoch voting time can be changed more that once
    function startOfEpoch(uint256 epoch) public view override returns (uint256) {
        if (epoch < currentEpoch()) revert EpochInThePast(epoch, currentEpoch());
        uint256 epochsSinceVotingPeriodChange = epoch - _votingPeriodChangedEpoch;

        return _votingPeriodChangedBlockNumber + epochsSinceVotingPeriodChange * _votingPeriod;
    }

    /// @dev Allows batch voting
    /// @notice Uses same params as castVote, but in arrays.
    /// @param proposalIds an array of proposalIds
    /// @param support an array of vote values for each proposal
    function castVotes(uint256[] calldata proposalIds, uint8[] calldata support)
        public
        override
        returns (uint256[] memory)
    {
        if (proposalIds.length != support.length) {
            revert ArrayLengthsMismatch();
        }

        uint256[] memory results = new uint256[](proposalIds.length);
        for (uint256 i; i < proposalIds.length;) {
            results[i] = castVote(proposalIds[i], support[i]);
            unchecked {
                ++i;
            }
        }
        return results;
    }

    /// @dev Allows batch voting
    /// @notice Uses same params as castVote, but in arrays.
    /// @param proposalIds an array of proposalIds
    /// @param support an array of vote values for each proposal
    /// @param v an array of v values for each proposal signature
    /// @param r an array of r values for each proposal signature
    /// @param s an array of s values for each proposal signature
    function castVotesBySig(
        uint256[] calldata proposalIds,
        uint8[] calldata support,
        uint8[] calldata v,
        bytes32[] calldata r,
        bytes32[] calldata s
    ) public virtual returns (uint256[] memory) {
        if (
            proposalIds.length != support.length || proposalIds.length != v.length || proposalIds.length != r.length
                || proposalIds.length != s.length
        ) {
            revert ArrayLengthsMismatch();
        }

        uint256[] memory results = new uint256[](proposalIds.length);
        for (uint256 i; i < proposalIds.length;) {
            results[i] = castVoteBySig(proposalIds[i], support[i], v[i], r[i], s[i]);
            unchecked {
                ++i;
            }
        }
        return results;
    }

    /// @dev Allows provide EIP-712 digest for vote by sig
    /// @param proposalId the proposal id
    /// @param support yes or no
    function hashVote(uint256 proposalId, uint8 support) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support)));
    }

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Update voting time only by SPOG
    /// @param newVotingTime New voting time
    function updateVotingTime(uint256 newVotingTime) external override onlySPOG {
        emit VotingPeriodUpdated(_votingPeriod, newVotingTime);

        _votingPeriod = newVotingTime;
        _votingPeriodChangedBlockNumber = block.number;
        _votingPeriodChangedEpoch = currentEpoch();
    }

    function registerEmergencyProposal(uint256 proposalId) external override onlySPOG {
        emergencyProposals[proposalId] = true;
    }

    function turnOnEmergencyVoting() external override onlySPOG {
        _emergencyVotingIsOn = true;
    }

    function turnOffEmergencyVoting() external override onlySPOG {
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
    ) public override(Governor, GovernorBase) returns (uint256) {
        // update epochProposalsCount. Proposals are voted on in the next epoch
        epochProposalsCount[currentEpoch() + 1]++;

        // allow only 1 SPOG change with no value per proposal
        if (targets.length != 1 || targets[0] != address(this) || values[0] != 0) {
            revert InvalidProposal();
        }

        bytes4 executableFuncSelector = bytes4(calldatas[0]);
        if (ISPOG(spogAddress).governedMethods(executableFuncSelector)) {
            revert NotGovernedMethod(executableFuncSelector);
        }

        uint256 proposalId = super.propose(targets, values, calldatas, description);
        // Check all methods for vote governance
        if (executableFuncSelector == ISPOG.addNewList.selector) {
            _proposalTypes[proposalId] = ProposalType.Vote;
        }

        // _payFee(executableFuncSelector);

        // // Inflate Vote and Value token supply unless method is reset or emergencyRemove
        // if (executableFuncSelector != this.reset.selector && executableFuncSelector != this.emergencyRemove.selector) {
        //     _inflateRewardTokens();
        // }

        // // Only $VALUE governance proposals
        // if (executableFuncSelector == this.reset.selector) {
        //     valueGovernor.turnOnEmergencyVoting();
        //     uint256 valueProposalId = valueGovernor.propose(targets, values, calldatas, description);
        //     valueGovernor.turnOffEmergencyVoting();

        //     emit NewValueQuorumProposal(valueProposalId);
        //     return valueProposalId;
        // }

        // // $VALUE and $VOTE governance proposals
        // // If we request to change config parameter, value governance should vote too
        // if (executableFuncSelector == this.change.selector) {
        //     uint256 voteProposalId = voteGovernor.propose(targets, values, calldatas, description);
        //     uint256 valueProposalId = valueGovernor.propose(targets, values, calldatas, description);

        //     // proposal ids should match
        //     if (valueProposalId != voteProposalId) {
        //         revert ValueVoteProposalIdsMistmatch(voteProposalId, valueProposalId);
        //     }

        //     emit NewDoubleQuorumProposal(voteProposalId);
        //     return voteProposalId;
        // }

        // // Only $VOTE governance proposals
        // uint256 proposalId;

        // // prevent proposing a list that can be changed before execution
        // if (executableFuncSelector == this.addNewList.selector) {
        //     address listParams = _extractAddressTypeParamsFromCalldata(calldatas[0]);
        //     if (IList(listParams).admin() != address(this)) {
        //         revert ListAdminIsNotSPOG();
        //     }
        // }

        // // Register emergency proposal with vote governor
        // if (executableFuncSelector == this.emergencyRemove.selector) {
        //     voteGovernor.turnOnEmergencyVoting();

        //     proposalId = voteGovernor.propose(targets, values, calldatas, description);
        //     voteGovernor.registerEmergencyProposal(proposalId);

        //     voteGovernor.turnOffEmergencyVoting();

        //     emit NewEmergencyProposal(proposalId);
        // } else {
        //     proposalId = voteGovernor.propose(targets, values, calldatas, description);
        //     emit NewVoteQuorumProposal(proposalId);
        // }

        return super.propose(targets, values, calldatas, description);
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
    function state(uint256 proposalId) public view override(Governor, GovernorBase) returns (ProposalState) {
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

    // /// @dev Accessor to the internal vote counts.
    // function proposalVoteVotes(uint256 proposalId) public view override returns (uint256 noVotes, uint256 yesVotes) {
    //     ProposalVote storage proposalVote = _proposalVotes[proposalId];
    //     return (proposalVote.noVotes, proposalVote.yesVotes);
    // }

    /**
     * @dev Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
     */
    function voteQuorum(uint256 timepoint) public view virtual returns (uint256) {
        return (vote.getPastTotalSupply(timepoint) * quorumNumerator(timepoint)) / quorumDenominator();
    }

    /**
     * @dev Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
     */
    function valueQuorum(uint256 timepoint) public view virtual returns (uint256) {
        return (value.getPastTotalSupply(timepoint) * quorumNumerator(timepoint)) / quorumDenominator();
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

    fallback() external {
        revert("SPOGGovernor: non-existent function");
    }
}
