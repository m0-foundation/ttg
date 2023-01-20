// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ISPOGVote} from "./interfaces/ISPOGVote.sol";

import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

// May be handy?
// import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";

contract GovSPOG is GovernorVotesQuorumFraction {
    ISPOGVote public immutable spogVote;

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
        ISPOGVote spogVoteAddress,
        uint256 quorumNumeratorValue,
        uint256 _voteTime
    )
        GovernorVotesQuorumFraction(quorumNumeratorValue)
        GovernorVotes(spogVoteAddress)
        Governor("GovSPOG")
    {
        spogVote = spogVoteAddress;
        voteTime = _voteTime;
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

    // The following functions are overrides required by Solidity.

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

    // TODO: check if these are needed

    // function quorum(uint256 blockNumber)
    //     public
    //     view
    //     override(GovernorVotesQuorumFraction)
    //     returns (uint256)
    // {
    //     return super.quorum(blockNumber);
    // }

    // function state(uint256 proposalId)
    //     public
    //     view
    //     override
    //     returns (ProposalState)
    // {
    //     return super.state(proposalId);
    // }

    // function propose(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     string memory description
    // ) public override returns (uint256) {
    //     return super.propose(targets, values, calldatas, description);
    // }

    // function _execute(
    //     uint256 proposalId,
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) internal override {
    //     super._execute(proposalId, targets, values, calldatas, descriptionHash);
    // }

    // function _cancel(
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory calldatas,
    //     bytes32 descriptionHash
    // ) internal override returns (uint256) {
    //     return super._cancel(targets, values, calldatas, descriptionHash);
    // }

    // function _executor() internal view override returns (address) {
    //     return super._executor();
    // }
}
