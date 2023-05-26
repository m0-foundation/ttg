// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import "src/interfaces/IList.sol";
import "src/core/governor/DualGovernorQuorum.sol";

/// @title SPOG Dual Governor Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin.
contract DualGovernor is DualGovernorQuorum {
    // @note minimum voting delay in blocks
    uint256 public constant MINIMUM_VOTING_DELAY = 1;

    uint256 private immutable _votingPeriod;
    uint256 private immutable _start;

    ISPOG public spog;
    mapping(uint256 => bool) public emergencyProposals;

    // @note voting with no delay is required for certain proposals
    bool private _emergencyVotingIsOn;

    // private mappings
    mapping(uint256 => ProposalVote) private _proposalVotes;
    mapping(uint256 => ProposalType) private _proposalTypes;
    // epoch => proposals info
    mapping(uint256 => EpochBasic) private _epochBasic;

    /// @param name The name of the governor
    /// @param vote The address of the $VOTE token
    /// @param value The address of the $VALUE token
    /// @param voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param votingPeriod_ The duration of a voting epochs for governor and auctions in blocks
    constructor(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        uint256 votingPeriod_
    ) DualGovernorQuorum(name, vote, value, voteQuorum, valueQuorum) {
        // TODO: sanity checks
        _votingPeriod = votingPeriod_;
        // TODO: should setting SPOG be start of counting epochs ?
        _start = block.number;
    }

    function initSPOGAddress(address _spog) external override {
        if (address(spog) != address(0)) revert AlreadyInitialized();
        if (_spog == address(0)) revert ZeroSPOGAddress();

        spog = ISPOG(_spog);
        // initialize tokens
        vote.initSPOGAddress(_spog);
        value.initSPOGAddress(_spog);
    }

    /// @dev get current epoch number - 0, 1, 2, 3, .. etc
    function currentEpoch() public view override returns (uint256) {
        return (block.number - _start) / _votingPeriod;
    }

    /// @dev get `block.number` of the start of the given epoch
    /// we can correctly calculate start of epochs only for current and future epochs
    /// it happens because epoch voting time can be changed more than once
    function startOf(uint256 epoch) public view override returns (uint256) {
        return _start + epoch * _votingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getProposalType(bytes4 func) internal view virtual returns (ProposalType) {
        if (
            func == this.updateVoteQuorumNumerator.selector || func == this.updateValueQuorumNumerator.selector
                || func == ISPOG.changeTaxRange.selector
        ) {
            return ProposalType.Double;
        }

        if (func == ISPOG.reset.selector) {
            return ProposalType.Value;
        }

        return ProposalType.Vote;
    }

    function isGovernedMethod(bytes4 func) public pure returns (bool) {
        return func == this.updateVoteQuorumNumerator.selector || func == this.updateValueQuorumNumerator.selector;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
        // Sanity checks
        if (values[0] != 0) revert InvalidValue();
        if (targets.length != 1) revert TooManyTargets();
        address target = targets[0];
        bytes4 func = bytes4(calldatas[0]);
        if (target != address(this) && target != address(spog)) revert InvalidTarget();
        if (target == address(this) && !isGovernedMethod(func)) revert InvalidMethod();
        if (target == address(spog) && !spog.isGovernedMethod(func)) revert InvalidMethod();
        // prevent proposing a list that can be changed before execution
        // TODO: potentially this should be part of pre-validation logic
        if (func == ISPOG.addNewList.selector) {
            address list = _extractAddressTypeParamsFromCalldata(calldatas[0]);
            if (IList(list).admin() != address(spog)) revert ListAdminIsNotSPOG();
        }

        spog.chargeFee(msg.sender, func);

        uint256 proposalId;
        ProposalType proposalType = _getProposalType(func);
        _proposalTypes[proposalId] = proposalType;
        if (func == ISPOG.reset.selector || func == ISPOG.emergency.selector) {
            _emergencyVotingIsOn = true;
            proposalId = super.propose(targets, values, calldatas, description);
            _emergencyVotingIsOn = false;
        } else {
            // do not inflate tokens for emergency and reset proposals
            spog.inflateRewardTokens();
            proposalId = super.propose(targets, values, calldatas, description);
        }

        if (func == ISPOG.emergency.selector) {
            emergencyProposals[proposalId] = true;
        }

        /// @dev proposals are voted on in the next epoch
        uint256 nextEpoch = currentEpoch() + 1;
        _epochBasic[nextEpoch].numProposals += 1;

        emit NewProposal(nextEpoch, proposalId, proposalType);
        return proposalId;
    }

    /// @notice override to count user activity in epochs
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        require(state(proposalId) == ProposalState.Active, "DualGovernor: vote not currently active");

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

        EpochBasic storage epochBasic = _epochBasic[epoch];
        // update number of proposals account voted for in current epoch
        epochBasic.numVotedOn[msg.sender] += 1;

        // update cumulative vote weight for epoch if user voted in all proposals
        if (epochBasic.numVotedOn[msg.sender] == epochBasic.numProposals) {
            epochBasic.totalVotesWeight += weight;
        }
    }

    function epochTotalVotesWeight(uint256 epoch) external view returns (uint256) {
        return _epochBasic[epoch].totalVotesWeight;
    }

    function isActiveParticipant(uint256 epoch, address account) external view returns (bool) {
        EpochBasic storage epochBasic = _epochBasic[epoch];
        return epochBasic.numVotedOn[account] == epochBasic.numProposals;
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
        return _emergencyVotingIsOn ? MINIMUM_VOTING_DELAY : startOf(currentEpoch() + 1) - block.number;
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    /// @notice extract address params from the call data
    /// @param callData The call data with selector in first 4 bytes
    /// @dev used to inspect params before allowing proposal
    function _extractAddressTypeParamsFromCalldata(bytes memory callData)
        internal
        pure
        returns (address targetParams)
    {
        assembly {
            // byte offset to represent function call data. 4 bytes funcSelector plus address 32 bytes
            let offset := 36
            // add offset so we pick from start of address params
            let addressPosition := add(callData, offset)
            // load the address params
            targetParams := mload(addressPosition)
        }
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
    function proposalVotes(uint256 proposalId) public view override returns (uint256, uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.voteNoVotes, proposalVote.voteYesVotes);
    }

    /// @dev Accessor to the internal vote counts.
    function proposalValueVotes(uint256 proposalId) public view override returns (uint256, uint256) {
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

        // TODO: fix checks with 0 quorum, do we really need it ?
        if (proposalType == ProposalType.Double) {
            return voteQuorum_ <= proposalVote.voteYesVotes && voteQuorum_ > 0
                && valueQuorum_ <= proposalVote.valueYesVotes && valueQuorum_ > 0;
        }
        if (proposalType == ProposalType.Value) {
            return valueQuorum_ <= proposalVote.valueYesVotes && valueQuorum_ > 0;
        }

        return voteQuorum_ <= proposalVote.voteYesVotes && voteQuorum_ > 0;
    }

    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(uint256 proposalId) internal view override returns (bool) {
        return _quorumReached(proposalId);
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

    function _countVote(uint256 proposalId, address account, uint8 support, uint256 votes, bytes memory)
        internal
        virtual
        override
    {
        _countVote(proposalId, account, support, votes, 0, "");
    }

    fallback() external {
        revert("DualGovernor: non-existent function");
    }
}
