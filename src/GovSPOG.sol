// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ISPOGVote} from "./interfaces/ISPOGVote.sol";

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

// May be handy?
// import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";

contract GovSPOG is GovernorVotesQuorumFraction {
    ISPOGVote public immutable spogVote;
    address public spogAddress;

    uint256 public voteTime;

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

    constructor(
        ISPOGVote spogVoteContract,
        uint256 quorumNumeratorValue,
        uint256 _voteTime,
        string memory name_
    )
        GovernorVotesQuorumFraction(quorumNumeratorValue)
        GovernorVotes(spogVoteContract)
        Governor(name_)
    {
        // spogAddress = _spogAddress;
        spogVote = spogVoteContract;
        voteTime = _voteTime;
    }

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external {
        require(spogAddress == address(0), "GovSPOG: spogAddress already set");
        spogAddress = _spogAddress;
    }

    /**
     * @dev See {IGovernor-hasVoted}.
     */
    function hasVoted(uint256 proposalId, address account)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev Accessor to the internal vote counts.
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (uint256 noVotes, uint256 yesVotes)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.noVotes, proposalVote.yesVotes);
    }

    /**
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) <= proposalVote.yesVotes;
    }

    /// @dev See {Governor-_countVote}.
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support
    ) internal virtual {
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

    function votingDelay() public pure override returns (uint256) {
        return 1; // 1 block
    }

    function votingPeriod() public view override returns (uint256) {
        return voteTime;
    }

    function _voteSucceeded(uint256 proposalId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return _quorumReached(proposalId);
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256,
        bytes memory
    ) internal virtual override {
        _countVote(proposalId, account, support);
    }

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
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

    /// @dev Update quorum numerator only by SPOG
    /// @param newQuorumNumerator New quorum numerator
    function updateQuorumNumerator(uint256 newQuorumNumerator)
        external
        override
    {
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
        voteTime = newVotingTime;
    }

    /***************************************************/
    /******** Prototype Helpers - NOT FOR PROD ********/
    /*************************************************/
    function mint(address _account, uint256 _amount) external {
        spogVote.mint(_account, _amount);
    }
}
