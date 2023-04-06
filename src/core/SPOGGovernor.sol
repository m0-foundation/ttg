// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

/// @title SPOG Governor Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin. It uses the GovernorVotesQuorumFraction contract and its inherited contracts to implement quorum and voting power. The goal is to create a modular Governance contract which SPOG can replace if needed.
contract SPOGGovernor is GovernorVotesQuorumFraction {
    ISPOGVotes public immutable votingToken;
    uint256 private _votingPeriod;
    address public spogAddress;
    uint256 public startOfNextVotingPeriod;
    uint256 public currentVotingPeriodEpoch;

    /// @dev Supported vote types.
    enum VoteType {
        No,
        Yes
    }

    struct ProposalVote {
        uint256 noVotes;
        uint256 yesVotes;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => ProposalVote) private _proposalVotes;
    // epoch => proposalCount
    mapping(uint256 => uint256) public epochProposalsCount;
    // address => epoch => number of votes
    mapping(address => mapping(uint256 => uint256)) public accountEpochVotes;

    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    constructor(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    ) GovernorVotesQuorumFraction(quorumNumeratorValue) GovernorVotes(votingTokenContract) Governor(name_) {
        votingToken = votingTokenContract;
        _votingPeriod = votingPeriod_;

        // trigger epoch 0
        startOfNextVotingPeriod = startOfNextVotingPeriod + _votingPeriod;
    }

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external {
        require(spogAddress == address(0), "SPOGGovernor: spogAddress already set");

        votingToken.initSPOGAddress(_spogAddress);
        spogAddress = _spogAddress;
    }

    /// @dev Accessor to the internal vote counts.
    function proposalVotes(uint256 proposalId) public view virtual returns (uint256 noVotes, uint256 yesVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.noVotes, proposalVote.yesVotes);
    }

    /// @dev it updates startOfNextVotingPeriod if needed. Used in propose, execute and castVote calls
    function updateStartOfNextVotingPeriod() public {
        if (block.number >= startOfNextVotingPeriod) {
            // move any unclaimed votingToken inflation rewards to the vault
            address vault = ISPOG(spogAddress).vault();
            votingToken.transfer(vault, votingToken.balanceOf(address(this)));

            // update startOfNextVotingPeriod
            startOfNextVotingPeriod = startOfNextVotingPeriod + _votingPeriod;

            currentVotingPeriodEpoch++;

            // trigger token votingToken inflation
            uint256 amountToIncreaseSupplyBy = ISPOG(spogAddress).tokenInflationCalculation();
            votingToken.mint(address(this), amountToIncreaseSupplyBy);
        }
    }

    // ********** Setters ********** //

    /// @dev Update quorum numerator only by SPOG
    /// @param newQuorumNumerator New quorum numerator
    function updateQuorumNumerator(uint256 newQuorumNumerator) external override {
        require(msg.sender == spogAddress, "SPOGGovernor: only SPOG can update quorum numerator");
        _updateQuorumNumerator(newQuorumNumerator);
    }

    /// @dev Update voting time only by SPOG
    /// @param newVotingTime New voting time
    function updateVotingTime(uint256 newVotingTime) external {
        require(msg.sender == spogAddress, "SPOGGovernor: only SPOG can update voting time");

        _votingPeriod = newVotingTime;
        emit VotingPeriodSet(_votingPeriod, newVotingTime);
    }

    // ********** Override functions ********** //

    /// @notice override to use updateStartOfNextVotingPeriod
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        require(msg.sender == spogAddress, "SPOGGovernor: only SPOG can propose");

        updateStartOfNextVotingPeriod();

        // update epochProposalsCount
        epochProposalsCount[currentVotingPeriodEpoch]++;

        return super.propose(targets, values, calldatas, description);
    }

    /// @notice override to use updateStartOfNextVotingPeriod
    /**
     * @dev Hook after execution is triggered.
     */
    function _afterExecute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        updateStartOfNextVotingPeriod();
        super._afterExecute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @notice override to use updateStartOfNextVotingPeriod
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        updateStartOfNextVotingPeriod();

        _updateAccountEpochVotes();

        _withdrawVotingTokenInflationRewards();

        return super._castVote(proposalId, account, support, reason, params);
    }

    /// @dev update epoch votes for address
    function _updateAccountEpochVotes() private {
        uint256 relevantEpochForEpochVoteCount = currentVotingPeriodEpoch - 1;

        // update accountEpochVotes
        accountEpochVotes[msg.sender][relevantEpochForEpochVoteCount]++;
    }

    /// @dev withdraw pro-rata votingToken inflation rewards when account voted in all proposals from current epoch
    function _withdrawVotingTokenInflationRewards() private {
        uint256 relevantEpochForEpochVoteCount = currentVotingPeriodEpoch - 1;

        if (
            accountEpochVotes[msg.sender][relevantEpochForEpochVoteCount]
                == epochProposalsCount[relevantEpochForEpochVoteCount]
        ) {
            uint256 amountToWithdraw = votingToken.balanceOf(address(this)) / votingToken.totalSupply();
            votingToken.transfer(msg.sender, amountToWithdraw);
        }
    }

    /// @dev See {IGovernor-hasVoted}.
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /// @dev See {Governor-_quorumReached}.
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) > 0 && quorum(proposalSnapshot(proposalId)) <= proposalVote.yesVotes;
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(uint256 proposalId, address account, uint8 support, uint256, bytes memory)
        internal
        virtual
        override
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        require(!proposalVote.hasVoted[account], "SPOGGovernor: vote already cast");
        proposalVote.hasVoted[account] = true;

        uint256 votes = _getVotes(account, proposalSnapshot(proposalId), "");

        if (support == uint8(VoteType.No)) {
            proposalVote.noVotes += votes;
        } else {
            proposalVote.yesVotes += votes;
        }
    }

    function votingDelay() public view override returns (uint256) {
        if (startOfNextVotingPeriod > block.number) {
            return startOfNextVotingPeriod - block.number;
        }

        revert("SPOGGovernor: StartOfNextVotingPeriod must be updated");
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        return _quorumReached(proposalId);
    }

    /// @dev See {IGovernor-COUNTING_MODE}.
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=bravo";
    }

    fallback() external {
        revert("SPOGGovernor: non-existent function");
    }
}
