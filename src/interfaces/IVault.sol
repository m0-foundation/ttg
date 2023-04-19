// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

interface IVault {

    event EpochRewardsDeposit(uint256 indexed epoch, address token, uint256 amount);
    event VoteTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);
    event ValueTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address auction, uint256 amount);

    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external;

    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external;

    function reclaimUnsoldVoteTokens(address auction) external;

    function withdrawVoteTokenRewards() external;

    function withdrawValueTokenRewards() external;
}
