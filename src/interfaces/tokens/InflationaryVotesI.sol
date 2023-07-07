// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface InflationaryVotesI is IVotes {
    function getPastBalance(address account, uint256 blockNumber) external view returns (uint256);
    function getPastTotalBalanceSupply(uint256 blockNumber) external view returns (uint256);
    function addVotingPower(address account, uint256 amount) external;
    function claimVoteRewards() external returns (uint256);
    function totalVotes() external view returns (uint256);
}
