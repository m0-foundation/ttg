// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IGovernorVotesQuorumFraction {
    function quorumNumerator() external view returns (uint256);

    function quorumNumerator(uint256 blockNumber) external view returns (uint256);

    function quorumDenominator() external view returns (uint256);

    function updateQuorumNumerator(uint256 newQuorumNumerator) external;
}
