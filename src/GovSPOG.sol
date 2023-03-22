// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ISPOGVotes} from "./interfaces/ISPOGVotes.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

/// @title SPOG Governance Contract
/// @notice This contract is used to govern the SPOG protocol. It is a modified version of the Governor contract from OpenZeppelin. It uses the GovernorVotesQuorumFraction contract and its inherited contracts to implement quorum and voting power. The goal is to create a modular Governance contract which SPOG can replace if needed.
contract GovSPOG is GovernorVotesQuorumFraction {
    ISPOGVotes public immutable votingToken;
    address public spogAddress;
    uint256 private _votingPeriod;
    uint256 public startOfNextVotingPeriod;

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

    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    constructor(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    )
        GovernorVotesQuorumFraction(quorumNumeratorValue)
        GovernorVotes(votingTokenContract)
        Governor(name_)
    {
        votingToken = votingTokenContract;
        _votingPeriod = votingPeriod_;

        startOfNextVotingPeriod = block.number + _votingPeriod;
    }

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external {
        require(spogAddress == address(0), "GovSPOG: spogAddress already set");
        spogAddress = _spogAddress;
    }

    /// @dev Accessor to the internal vote counts.
    function proposalVotes(
        uint256 proposalId
    ) public view virtual returns (uint256 noVotes, uint256 yesVotes) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.noVotes, proposalVote.yesVotes);
    }

    /// @dev it updates startOfNextVotingPeriod if needed. Used in propose, execute and castVote calls
    function updateStartOfNextVotingPeriod() public {
        if (block.number >= startOfNextVotingPeriod) {
            startOfNextVotingPeriod = startOfNextVotingPeriod + _votingPeriod;
            uint256 amountToIncreaseSupplyBy = ISPOG(spogAddress)
                .tokenInflationCalculation();

            votingToken.mint(address(this), amountToIncreaseSupplyBy); // TODO: change address to a Vault contract
        }
    }

    // ********** Setters ********** //

    /// @dev Update quorum numerator only by SPOG
    /// @param newQuorumNumerator New quorum numerator
    function updateQuorumNumerator(
        uint256 newQuorumNumerator
    ) external override {
        require(
            msg.sender == spogAddress,
            "GovSPOG: only SPOG can update quorum numerator"
        );
        _updateQuorumNumerator(newQuorumNumerator);
    }

    /// @dev Update voting time only by SPOG
    /// @param newVotingTime New voting time
    function updateVotingTime(uint256 newVotingTime) external {
        require(
            msg.sender == spogAddress,
            "GovSPOG: only SPOG can update voting time"
        );

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
        updateStartOfNextVotingPeriod();
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
        super._afterExecute(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /// @notice override to use updateStartOfNextVotingPeriod
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override returns (uint256) {
        updateStartOfNextVotingPeriod();
        return super._castVote(proposalId, account, support, reason, params);
    }

    /// @dev See {IGovernor-hasVoted}.
    function hasVoted(
        uint256 proposalId,
        address account
    ) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /// @dev See {Governor-_quorumReached}.
    function _quorumReached(
        uint256 proposalId
    ) internal view virtual override returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) <= proposalVote.yesVotes;
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256,
        bytes memory
    ) internal virtual override {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        require(!proposalVote.hasVoted[account], "GovSPOG: vote already cast");
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
        } else {
            revert("GovSPOG: StartOfNextVotingPeriod must be updated");
        }
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    /// @dev See {Governor-_voteSucceeded}.
    function _voteSucceeded(
        uint256 proposalId
    ) internal view virtual override returns (bool) {
        return _quorumReached(proposalId);
    }

    /// @dev See {IGovernor-COUNTING_MODE}.
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "support=bravo&quorum=bravo";
    }
}
