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
    // address => epoch => number of proposals voted on
    mapping(address => mapping(uint256 => uint256)) public accountEpochNumProposalsVotedOn;
    // epoch => vote inflation amount
    mapping(uint256 => uint256) public epochVotingTokenInflationAmount;
    // epoch => vote token supply at epoch start
    mapping(uint256 => uint256) public epochVotingTokenSupply;
    // epoch => cumulative epoch vote weight casted
    mapping(uint256 => uint256) public epochSumOfVoteWeight;
    // address => epoch => epoch vote weight
    mapping(address => mapping(uint256 => uint256)) public accountEpochVoteWeight;

    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event VotingTokenInflation(uint256 indexed epoch, uint256 amount);
    event VotingTokenInflationWithdrawn(address indexed voter, uint256 amount);
    event EpochVotingTokenSupplySet(uint256 indexed epoch, uint256 amount);

    constructor(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    ) GovernorVotesQuorumFraction(quorumNumeratorValue) GovernorVotes(votingTokenContract) Governor(name_) {
        votingToken = votingTokenContract;
        _votingPeriod = votingPeriod_;

        // trigger epoch 0
        startOfNextVotingPeriod = block.number + _votingPeriod;
        currentVotingPeriodEpoch = 0;
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
            // move any votingToken stuck in this contract to the vault
            address vault = ISPOG(spogAddress).vault();
            votingToken.transfer(vault, votingToken.balanceOf(address(this)));

            // update currentVotingPeriodEpoch
            currentVotingPeriodEpoch++;

            // update epochVotingTokenSupply
            epochVotingTokenSupply[currentVotingPeriodEpoch] = votingToken.getPastTotalSupply(startOfNextVotingPeriod);
            emit EpochVotingTokenSupplySet(currentVotingPeriodEpoch, epochVotingTokenSupply[currentVotingPeriodEpoch]);

            // update startOfNextVotingPeriod
            startOfNextVotingPeriod = startOfNextVotingPeriod + _votingPeriod;

            // trigger token votingToken inflation
            uint256 amountToIncreaseSupplyBy = ISPOG(spogAddress).tokenInflationCalculation();

            epochVotingTokenInflationAmount[currentVotingPeriodEpoch] = amountToIncreaseSupplyBy;

            votingToken.mint(vault, amountToIncreaseSupplyBy); // send inflation to vault

            emit VotingTokenInflation(currentVotingPeriodEpoch, amountToIncreaseSupplyBy);
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

        // update epochProposalsCount. Proposals are voted on in the next epoch
        epochProposalsCount[currentVotingPeriodEpoch + 1]++;

        return super.propose(targets, values, calldatas, description);
    }

    /// @notice override to use updateStartOfNextVotingPeriod and check that caller is SPOG
    /**
     * @dev Internal execution mechanism. Can be overridden to implement different execution mechanism
     */
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        require(msg.sender == spogAddress, "SPOGGovernor: only SPOG can execute");

        updateStartOfNextVotingPeriod();
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @notice override to use updateStartOfNextVotingPeriod
    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params)
        internal
        virtual
        override
        returns (uint256)
    {
        updateStartOfNextVotingPeriod();

        if (currentVotingPeriodEpoch == 0) revert("Governor: vote not currently active"); // no voting in epoch 0

        _updateAccountEpochVotes();
        _updateAccountEpochVoteWeight(proposalId);

        return super._castVote(proposalId, account, support, reason, params);
    }

    /// @dev update epoch votes for address
    function _updateAccountEpochVotes() private {
        accountEpochNumProposalsVotedOn[msg.sender][currentVotingPeriodEpoch]++;
    }

    /// @dev update epoch vote weight for address and cumulative vote weight casted in epoch
    function _updateAccountEpochVoteWeight(uint256 proposalId) private {
        uint256 voteWeight = _getVotes(msg.sender, proposalSnapshot(proposalId), "");

        // update address vote weight for epoch
        if (accountEpochVoteWeight[msg.sender][currentVotingPeriodEpoch] == 0) {
            accountEpochVoteWeight[msg.sender][currentVotingPeriodEpoch] = voteWeight;
        }

        // update cumulative vote weight for epoch if user voted in all proposals
        if (
            accountEpochNumProposalsVotedOn[msg.sender][currentVotingPeriodEpoch]
                == epochProposalsCount[currentVotingPeriodEpoch]
        ) {
            epochSumOfVoteWeight[currentVotingPeriodEpoch] = epochSumOfVoteWeight[currentVotingPeriodEpoch] + voteWeight;
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
