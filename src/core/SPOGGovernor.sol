// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {IVault} from "src/interfaces/IVault.sol";
import {IGovernorVotesQuorumFraction} from "src/interfaces/IGovernorVotesQuorumFraction.sol";

/// @title SPOG Governor Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin. It uses the GovernorVotesQuorumFraction contract and its inherited contracts to implement quorum and voting power. The goal is to create a modular Governance contract which SPOG can replace if needed.
contract SPOGGovernor is ISPOGGovernor, GovernorVotesQuorumFraction {
    // @note minimum voting delay in blocks
    uint256 public constant MINIMUM_VOTING_DELAY = 1;

    ISPOGVotes public immutable override votingToken;
    address public override spogAddress;

    uint256 private _votingPeriod;
    uint256 private _votingPeriodChangedBlockNumber;
    uint256 private _votingPeriodChangedEpoch;

    // @note voting with no delay is required for certain proposals
    bool private emergencyVotingIsOn;

    /// @dev Supported vote types.
    enum VoteType {
        No,
        Yes
    }

    // private mappings
    mapping(uint256 => ProposalVote) private _proposalVotes;

    // public mappings
    mapping(uint256 => bool) public override emergencyProposals;

    // epoch => proposalCount
    mapping(uint256 => uint256) public override epochProposalsCount;
    // address => epoch => number of proposals voted on
    mapping(address => mapping(uint256 => uint256)) public override accountEpochNumProposalsVotedOn;
    // epoch => cumulative epoch vote weight casted
    mapping(uint256 => uint256) public override epochSumOfVoteWeight;

    modifier onlySPOG() {
        if (msg.sender != spogAddress) revert CallerIsNotSPOG(msg.sender);

        _;
    }

    constructor(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    ) GovernorVotesQuorumFraction(quorumNumeratorValue) GovernorVotes(votingTokenContract) Governor(name_) {
        votingToken = votingTokenContract;
        _votingPeriod = votingPeriod_;
        _votingPeriodChangedBlockNumber = block.number;
    }

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external override {
        if (spogAddress != address(0)) {
            revert SPOGAddressAlreadySet(spogAddress);
        }

        votingToken.initSPOGAddress(_spogAddress);
        spogAddress = _spogAddress;
    }

    function quorumNumerator()
        public
        view
        virtual
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumNumerator();
    }

    function quorumNumerator(uint256 blockNumber)
        public
        view
        virtual
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumNumerator(blockNumber);
    }

    function quorumDenominator()
        public
        view
        virtual
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumDenominator();
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
    function startOfEpoch(uint256 epoch) public view override returns (uint256) {
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
        uint256 propLength = proposalIds.length;
        uint256 supLength = support.length;
        if (propLength != supLength) {
            revert ArrayLengthsMistmatch(propLength, supLength);
        }
        uint256[] memory results = new uint256[](propLength);
        for (uint256 i; i < propLength;) {
            results[i] = castVote(proposalIds[i], support[i]);
            unchecked {
                ++i;
            }
        }
        return results;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Update quorum numerator only by SPOG
    /// @param newQuorumNumerator New quorum numerator
    function updateQuorumNumerator(uint256 newQuorumNumerator)
        external
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        onlySPOG
    {
        _updateQuorumNumerator(newQuorumNumerator);
    }

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
        emergencyVotingIsOn = true;
    }

    function turnOffEmergencyVoting() external override onlySPOG {
        emergencyVotingIsOn = false;
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(Governor, IGovernor) onlySPOG returns (uint256) {
        // update epochProposalsCount. Proposals are voted on in the next epoch
        epochProposalsCount[currentEpoch() + 1]++;

        return super.propose(targets, values, calldatas, description);
    }

    /// @notice override to check that caller is SPOG
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override onlySPOG {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @notice override to count user activity in epochs
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        uint256 weight = super._castVote(proposalId, account, support, reason, params);

        _updateAccountEpochVotes();
        _updateAccountEpochVoteWeight(weight);

        return weight;
    }

    /// @dev update epoch votes for address
    function _updateAccountEpochVotes() private {
        accountEpochNumProposalsVotedOn[msg.sender][currentEpoch()]++;
    }

    /// @dev update epoch vote weight for address and cumulative vote weight casted in epoch
    function _updateAccountEpochVoteWeight(uint256 weight) private {
        uint256 epoch = currentEpoch();

        // update cumulative vote weight for epoch if user voted in all proposals
        if (accountEpochNumProposalsVotedOn[msg.sender][epoch] == epochProposalsCount[epoch]) {
            epochSumOfVoteWeight[epoch] += weight;
        }
    }

    /**
     * @dev Overridden version of the {Governor-state} function with added support for emergency proposals.
     */
    function state(uint256 proposalId) public view virtual override(Governor, IGovernor) returns (ProposalState) {
        ProposalState status = super.state(proposalId);

        // If emergency proposal is `Active` and quorum is reached, change status to `Succeeded` even if deadline is not passed yet.
        // Use only `_quorumReached` for this check, `_voteSucceeded` is not needed as it is the same.
        if (emergencyProposals[proposalId] && status == ProposalState.Active && _quorumReached(proposalId)) {
            return ProposalState.Succeeded;
        }

        return status;
    }

    function votingDelay() public view override returns (uint256) {
        return emergencyVotingIsOn ? MINIMUM_VOTING_DELAY : startOfNextEpoch() - block.number;
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            COUNTING MODULE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev See {IGovernor-COUNTING_MODE}.
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=alpha&quorum=alpha";
    }

    /// @dev See {IGovernor-hasVoted}.
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /// @dev Accessor to the internal vote counts.
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        override
        returns (uint256 noVotes, uint256 yesVotes)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.noVotes, proposalVote.yesVotes);
    }

    /// @dev See {Governor-_quorumReached}.
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        uint256 proposalQuorum = quorum(proposalSnapshot(proposalId));
        // if token has 0 supply, make sure that quorum was not reached
        // @dev short-circuiting the rare usecase of 0 supply check to save gas
        return proposalQuorum <= proposalVote.yesVotes && proposalQuorum > 0;
    }

    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        return _quorumReached(proposalId);
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(uint256 proposalId, address account, uint8 support, uint256 votes, bytes memory)
        internal
        virtual
        override
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalVote.hasVoted[account]) {
            revert AlreadyVoted(proposalId, account);
        }
        proposalVote.hasVoted[account] = true;

        if (support == uint8(VoteType.No)) {
            proposalVote.noVotes += votes;
        } else {
            proposalVote.yesVotes += votes;
        }
    }

    fallback() external {
        revert("SPOGGovernor: non-existent function");
    }
}
