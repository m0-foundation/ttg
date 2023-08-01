// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IGovernor } from "../ImportedInterfaces.sol";

// NOTE: Openzeppelin erroneously declared `IGovernor` as abstract contract, so this needs to follow suit.
abstract contract IDualGovernorQuorum is IGovernor {
    error ZeroVoteAddress();
    error ZeroValueAddress();
    error ZeroVoteQuorumNumerator();
    error ZeroValueQuorumNumerator();
    error VoteValueMismatch();
    error InvalidVoteQuorumNumerator();
    error InvalidValueQuorumNumerator();

    event VoteQuorumNumeratorUpdated(uint256 oldVoteQuorumNumerator, uint256 newVoteQuorumNumerator);
    event ValueQuorumNumeratorUpdated(uint256 oldValueQuorumNumerator, uint256 newValueQuorumNumerator);

    // Accessors for vote and value tokens
    function vote() external view virtual returns (address);

    function value() external view virtual returns (address);

    // Vote and value quorums
    function voteQuorumNumerator() external view virtual returns (uint256);

    function valueQuorumNumerator() external view virtual returns (uint256);

    function quorumDenominator() external view virtual returns (uint256);

    function voteQuorum(uint256 timepoint) external view virtual returns (uint256);

    function voteQuorumNumerator(uint256 timepoint) external view virtual returns (uint256);

    function valueQuorum(uint256 timepoint) external view virtual returns (uint256);

    function valueQuorumNumerator(uint256 timepoint) external view virtual returns (uint256);

    function updateVoteQuorumNumerator(uint256 newVoteQuorumNumerator) external virtual;

    function updateValueQuorumNumerator(uint256 newValueQuorumNumerator) external virtual;
}
