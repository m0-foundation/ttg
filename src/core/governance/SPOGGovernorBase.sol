// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
    GovernorVotesQuorumFraction,
    GovernorVotes,
    Governor,
    IGovernor as GovernorBase
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {ISPOGGovernor, IGovernorVotesQuorumFraction, ISPOGVotes} from "src/interfaces/ISPOGGovernor.sol";

/// @dev SPOG governor abstract contract. It sets up the OZ Governor contracts for SPOGGovernor.
abstract contract SPOGGovernorBase is ISPOGGovernor, GovernorBase, GovernorVotesQuorumFraction {
    address public spogAddress;

    constructor(ISPOGVotes votingTokenContract, uint256 quorumNumeratorValue, string memory name_)
        GovernorVotesQuorumFraction(quorumNumeratorValue)
        GovernorVotes(votingTokenContract)
        Governor(name_)
    {}

    modifier onlySPOG() {
        if (msg.sender != spogAddress) revert CallerIsNotSPOG(msg.sender);

        _;
    }

    /// @dev sets the spog address. Can only be called once.
    /// @param _spogAddress the address of the spog
    function initSPOGAddress(address _spogAddress) external virtual;

    function quorumNumerator()
        public
        view
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumNumerator();
    }

    function quorumNumerator(uint256 blockNumber)
        public
        view
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumNumerator(blockNumber);
    }

    function quorumDenominator()
        public
        view
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return GovernorVotesQuorumFraction.quorumDenominator();
    }

    /// @dev Update quorum numerator only by SPOG
    /// @param newQuorumNumerator New quorum numerator
    function updateQuorumNumerator(uint256 newQuorumNumerator)
        external
        override(GovernorVotesQuorumFraction, IGovernorVotesQuorumFraction)
        onlySPOG
    {
        _updateQuorumNumerator(newQuorumNumerator);
    }

    function castVotes(uint256[] calldata proposalIds, uint8[] calldata support)
        external
        virtual
        returns (uint256[] memory);
}
