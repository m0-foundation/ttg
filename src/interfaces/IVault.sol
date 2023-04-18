// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IVault {
    event VoteTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);
    event ValueTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);

    function withdrawVoteTokenRewards() external;

    function withdrawValueTokenRewards() external;

    function sellERC20(address token, uint256 amount) external;

}