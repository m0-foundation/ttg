// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernor } from "../../interfaces/ImportedInterfaces.sol";
import { ISPOG } from "../../interfaces/ISPOG.sol";
import { IVALUE, IVOTE } from "../../interfaces/ITokens.sol";

import { Governor } from "../../ImportedContracts.sol";
import { DualGovernorQuorum } from "./DualGovernorQuorum.sol";

/// @title SPOG Dual Governor Contract
/// @notice This contract is used to govern the SPOG protocol, adjusted to to have double token nature of governance
contract DualGovernor is DualGovernorQuorum {
    struct EpochBasic {
        uint256 numProposals;
        uint256 totalVotesWeight;
        mapping(address => uint256) numVotedOn;
        mapping(address => uint256) finishedVotingAt;
        bool withRewards;
    }

    struct ProposalVote {
        uint256 voteNoVotes;
        uint256 voteYesVotes;
        uint256 valueNoVotes;
        uint256 valueYesVotes;
        mapping(address => bool) hasVoted;
    }

    /// @notice Minimum voting delay in blocks for emergency proposals
    uint256 public constant MINIMUM_VOTING_DELAY = 1;

    /// @notice The SPOG contract
    address public spog;

    /// @notice The list of emergency proposals, (proposalId => true)
    mapping(uint256 proposalId => bool isEmergencyProposal) public emergencyProposals;

    /// @dev The voting period in blocks
    uint256 private immutable _votingPeriod;

    /// @dev The start of counting epochs
    uint256 private immutable _start;

    /// @dev The indicator of voting with `MINIMUM_VOTING_DELAY` delay is required proposal
    bool private _emergencyVotingIsOn;

    /// @dev Voting results for proposal: (proposalId => ProposalVote)
    mapping(uint256 proposalId => ProposalVote proposalVote) private _proposalVotes;

    /// @dev Proposal types: (proposalId => ProposalType)
    mapping(uint256 proposalId => ProposalType proposalVote) private _proposalTypes;

    /// @dev Basic information about epoch (epoch number => EpochBasic)
    mapping(uint256 epoch => EpochBasic epochBasic) private _epochBasic;

    /// @notice Constructs a new governor instance
    /// @param name The name of the governor
    /// @param vote The address of the $VOTE token
    /// @param value The address of the $VALUE token
    /// @param voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param valueQuorum The fraction of the current $VALUE supply voting "YES" for actions that require a
    ///                    `VALUE QUORUM`
    /// @param votingPeriod_ The duration of a voting epochs for governor and auctions in blocks
    constructor(
        string memory name,
        address vote,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        uint256 votingPeriod_
    ) DualGovernorQuorum(name, vote, value, voteQuorum, valueQuorum) {
        // Sanity checks
        if (votingPeriod_ == 0) revert ZeroVotingPeriod();

        // Set governor configuration
        _votingPeriod = votingPeriod_;

        // TODO: should setting SPOG be start of counting epochs ?
        _start = block.number;
    }

    /// @notice Initializes SPOG address
    /// @dev Adds additional initialization for tokens
    /// @param spog_ The address of the SPOG contract
    function initializeSPOG(address spog_) external {
        if (spog != address(0)) revert AlreadyInitialized();
        if (spog_ == address(0)) revert ZeroSPOGAddress();
        if (_start == 0) revert ZeroStart(); // should never happen, precaution

        spog = spog_;

        // initialize tokens
        IVOTE(vote).initializeSPOG(spog_);

        // TODO: find the way to avoid mistake with initialization for reset
        // TODO: do not fail if spog address has been already initialized for value token
        try IVALUE(value).initializeSPOG(spog_) {} catch {}
    }

    /// @notice Gets the current epoch number - 0, 1, 2, 3, .. etc
    /// @return current epoch number
    function currentEpoch() public view returns (uint256) {
        return (block.number - _start) / _votingPeriod;
    }

    /// @notice Gets the start block number of the given epoch
    /// @param epoch The epoch number
    /// @return `block.number` of the start of the epoch
    function startOf(uint256 epoch) public view returns (uint256) {
        return _start + epoch * _votingPeriod;
    }

    /// @dev Returns proposal type for given function selector
    /// @param func The function selector
    /// @return type of proposals
    function _getProposalType(bytes4 func) internal view virtual returns (ProposalType) {
        if (
            func == this.updateVoteQuorumNumerator.selector ||
            func == this.updateValueQuorumNumerator.selector ||
            func == ISPOG.changeTaxRange.selector
        ) {
            return ProposalType.Double;
        }

        if (func == ISPOG.reset.selector) {
            return ProposalType.Value;
        }

        return ProposalType.Vote;
    }

    /// @dev Returns whether the given function selector is a governed method
    /// @param func The function selector
    /// @return true if the function is governed, false otherwise
    function isGovernedMethod(bytes4 func) public pure returns (bool) {
        return func == this.updateVoteQuorumNumerator.selector || func == this.updateValueQuorumNumerator.selector;
    }

    /// @notice Creates a new proposal
    /// @dev One of main overridden methods of OZ governor interface, adjusted for SPOG needs
    /// @param targets The ordered list of target addresses for calls to be made
    /// @dev only one target is allowed and target address can be only SPOG or governor contract
    /// @param values The ordered list of values (i.e amounts) to be passed to the calls to be made
    /// @dev only one value is allowed and it should be 0
    /// @param calldatas The ordered list of function signatures and encoded parameters to be passed to each call
    /// @param description The proposal description field
    /// @return proposalId The id of the newly created proposal
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(IGovernor, Governor) returns (uint256) {
        // Sanity checks
        if (values[0] != 0) revert InvalidValue();
        if (targets.length != 1) revert TooManyTargets();

        address target = targets[0];
        bytes4 func = bytes4(calldatas[0]);

        if (target != address(this) && target != spog) revert InvalidTarget();
        if (target == address(this) && !isGovernedMethod(func)) revert InvalidMethod();
        if (target == spog && !ISPOG(spog).isGovernedMethod(func)) revert InvalidMethod();

        ISPOG(spog).chargeFee(_msgSender(), func);

        uint256 nextEpoch = currentEpoch() + 1;
        uint256 proposalId;
        if (func == ISPOG.emergency.selector || func == ISPOG.reset.selector) {
            _emergencyVotingIsOn = true;
            proposalId = super.propose(targets, values, calldatas, description);
            _emergencyVotingIsOn = false;

            emergencyProposals[proposalId] = true;
        } else {
            // proposals are voted on in the next epoch
            EpochBasic storage epochBasic = _epochBasic[nextEpoch];
            epochBasic.withRewards = true;
            epochBasic.numProposals += 1;

            proposalId = super.propose(targets, values, calldatas, description);
        }

        // Save proposal type
        ProposalType proposalType = _getProposalType(func);
        _proposalTypes[proposalId] = proposalType;

        emit Proposal(nextEpoch, proposalId, proposalType, targets[0], calldatas[0], description);

        return proposalId;
    }

    /// @notice Cast votes to count user activity in epochs
    /// @dev Allows batch voting
    /// @param proposalIds The ids of the proposals
    /// @param votes The values of the votes
    function castVotes(uint256[] calldata proposalIds, uint8[] calldata votes) public {
        address voter = _msgSender();
        require(proposalIds.length == votes.length, "DualGovernor: proposalIds and votes length mismatch");

        for (uint256 i = 0; i < proposalIds.length; i++) {
            _castVote(proposalIds[i], voter, votes[i], "");
        }
    }

    /// @dev Cast vote to count user activity in epochs
    /// @dev Overridden method of OZ governor interface adjusted for double governance nature of voting process
    /// @param proposalId The id of the proposal
    /// @param account The address of the account to vote for
    /// @param support The support value of the vote - 0 or 1
    /// @param reason The reason given for the vote by the voter
    /// @param params The parameters of the vote
    /// @return voteWeight The weight of vote
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override returns (uint256) {
        if (state(proposalId) != ProposalState.Active) revert ProposalIsNotInActiveState();

        ProposalType proposalType = _proposalTypes[proposalId];

        uint256 snapshot = proposalSnapshot(proposalId);

        uint256 voteWeight = (proposalType == ProposalType.Vote || proposalType == ProposalType.Double)
            ? _getVoteVotes(account, snapshot, params)
            : 0;

        uint256 valueWeight = (proposalType == ProposalType.Value || proposalType == ProposalType.Double)
            ? _getValueVotes(account, snapshot, params)
            : 0;

        _countVote(proposalId, account, support, voteWeight, valueWeight, params);

        // update total active votes and accrue rewards for non-emergency, non-reset proposals
        if (voteWeight > 0 && !emergencyProposals[proposalId]) {
            _registerVotesAndAccrueRewards(account, voteWeight);
        }

        // TODO: adjust weight we need to return ?
        if (params.length == 0) {
            emit VoteCast(account, proposalId, support, voteWeight, reason);
        } else {
            emit VoteCastWithParams(account, proposalId, support, voteWeight, reason, params);
        }

        return voteWeight;
    }

    /// @dev Update number of proposals account voted on and cumulative vote weight for the epoch
    /// @dev If voted on all active proposals, accrue VOTE voting power rewards
    /// @param account The the account that voted on proposals
    /// @param weight The vote weight of the account
    /// @return The reward vote weight of the account if all mandatory proposals were voted on
    function _registerVotesAndAccrueRewards(address account, uint256 weight) internal virtual returns (uint256) {
        uint256 epoch = currentEpoch();
        EpochBasic storage epochBasic = _epochBasic[epoch];

        // update number of proposals account voted for in current epoch
        epochBasic.numVotedOn[account] += 1;

        // if user voted for all proposals, update cumulative weight and give rewards
        if (!_hasFinishedVoting(epochBasic, account)) return 0;

        // update cumulative vote weight and save time when last proposal was voted on
        epochBasic.totalVotesWeight += weight;
        epochBasic.finishedVotingAt[account] = block.number;

        // calculate and mint VOTE voting power reward
        uint256 votesWeightReward = ISPOG(spog).getInflationReward(weight);
        IVOTE(vote).addVotingPower(account, votesWeightReward);

        // claim VALUE token reward by delegate
        // uint256 valueReward = epochVotes * spog.valueFixedInflation() / IVOTE(vote).getPastTotalVotes(epochStart);
        // TODO: make sure governor can mint here
        // IVALUE(value).mint(account, valueReward);

        emit VotingFinishedAndRewardsAccrued(account, epoch, block.number, votesWeightReward);

        return votesWeightReward;
    }

    /// @notice Gets total vote weight power for the epoch
    /// @param epoch The epoch number to get total vote weight for
    /// @return The total vote weight power for the epoch
    function epochTotalVotesWeight(uint256 epoch) external view returns (uint256) {
        return _epochBasic[epoch].totalVotesWeight;
    }

    function finishedVotingAt(uint256 epoch, address account) external view returns (uint256) {
        return _epochBasic[epoch].finishedVotingAt[account];
    }

    /// @notice Checks if account voted on all proposals in the epoch
    /// @param epoch The epoch number to check
    /// @param account The account to check
    /// @return True if account voted on all proposals in the epoch
    function hasFinishedVoting(uint256 epoch, address account) external view returns (bool) {
        EpochBasic storage epochBasic = _epochBasic[epoch];
        return _hasFinishedVoting(epochBasic, account);
    }

    function _hasFinishedVoting(EpochBasic storage epochBasic, address account) internal view returns (bool) {
        if (account == address(0)) return false;

        return epochBasic.withRewards && epochBasic.numVotedOn[account] == epochBasic.numProposals;
    }

    /// @notice Returns state of proposal
    /// @param proposalId The id of the proposal
    /// @return The state of the proposal
    /// @dev One of main overridden methods of OZ governor interface, adjusted for SPOG needs
    function state(uint256 proposalId) public view override(IGovernor, Governor) returns (ProposalState) {
        ProposalState status = super.state(proposalId);

        if (emergencyProposals[proposalId]) {
            // If emergency proposal is `Active` and quorum is reached, change status to `Succeeded`
            // Use only `_quorumReached` for this check, `_voteSucceeded` returns the same result
            if (status == ProposalState.Active && _quorumReached(proposalId)) {
                return ProposalState.Succeeded;
            }

            // emergency proposal expires in the same epoch it was voted on
            if (status == ProposalState.Succeeded) {
                return ProposalState.Expired;
            }
        }

        // Set state to `Expired` if proposal was not executed in the next epoch
        if (status == ProposalState.Succeeded) {
            uint256 expiresAt = proposalDeadline(proposalId) + _votingPeriod;

            if (block.number > expiresAt) {
                return ProposalState.Expired;
            }
        }

        return status;
    }

    /// @notice Returns the voting delay for proposal
    function votingDelay() public view override returns (uint256) {
        return _emergencyVotingIsOn ? MINIMUM_VOTING_DELAY : _currentEpochRemainder();
    }

    /// @notice Returns the voting period for proposal
    function votingPeriod() public view override returns (uint256) {
        return _emergencyVotingIsOn ? _currentEpochRemainder() : _votingPeriod;
    }

    /// @dev Returns the number of blocks left in the current epoch
    function _currentEpochRemainder() internal view returns (uint256) {
        return startOf(currentEpoch() + 1) - block.number - 1;
    }

    /// @dev Extracts address params from the call data
    /// @param callData The call data with function selector in the first 4 bytes
    /// @dev Used to inspect params before allowing proposal
    /// @return targetParams The params of function call
    function _extractFuncParams(bytes memory callData) internal pure returns (address targetParams) {
        assembly {
            // byte offset to represent function call data. 4 bytes funcSelector plus address 32 bytes
            let offset := 36
            // add offset so we pick from start of address params
            let addressPosition := add(callData, offset)
            // load the address params
            targetParams := mload(addressPosition)
        }
    }

    /******************************************************************************************************************/
    /*** COUNTING MODULE FUNCTIONS                                                                                  ***/
    /******************************************************************************************************************/

    /// @notice Implements OZ Governor counting module interface
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure override returns (string memory) {
        return "support=alpha&quorum=alpha";
    }

    /// @notice Implements OZ Governor counting module interface
    function hasVoted(uint256 proposalId, address account) public view override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /// @notice Implements OZ Governor counting module interface
    function proposalVotes(uint256 proposalId) public view returns (uint256, uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.voteNoVotes, proposalVote.voteYesVotes);
    }

    /// @notice Returns total value votes for proposal
    function proposalValueVotes(uint256 proposalId) public view returns (uint256, uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.valueNoVotes, proposalVote.valueYesVotes);
    }

    /// @notice Checks if quorum was reached taking into account type of proposals and vote and value votes
    /// @dev See {OZ Governor-_quorumReached} adjusted for double-governance nature of SPOG.
    function _quorumReached(uint256 proposalId) internal view override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        ProposalType proposalType = _proposalTypes[proposalId];
        uint256 snapshot = proposalSnapshot(proposalId);
        uint256 voteQuorum_ = voteQuorum(snapshot);
        uint256 valueQuorum_ = valueQuorum(snapshot);

        if (proposalType == ProposalType.Double) {
            return voteQuorum_ <= proposalVote.voteYesVotes && valueQuorum_ <= proposalVote.valueYesVotes;
        }

        if (proposalType == ProposalType.Value) return valueQuorum_ <= proposalVote.valueYesVotes;

        return voteQuorum_ <= proposalVote.voteYesVotes;
    }

    /// @notice Checks if proposal is successful
    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(uint256 proposalId) internal view override returns (bool) {
        return _quorumReached(proposalId);
    }

    /// @dev Counts both value and vote votes for proposal
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

        if (proposalVote.hasVoted[account]) revert AlreadyVoted();

        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.No)) {
            proposalVote.voteNoVotes += voteVotes;
            proposalVote.valueNoVotes += valueVotes;
        } else {
            proposalVote.voteYesVotes += voteVotes;
            proposalVote.valueYesVotes += valueVotes;
        }
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 votes,
        bytes memory
    ) internal virtual override {
        _countVote(proposalId, account, support, votes, 0, "");
    }
}
