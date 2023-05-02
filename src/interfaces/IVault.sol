// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

interface IVault {
    event EpochRewardsDeposit(uint256 indexed epoch, address token, uint256 amount);
    event TokenRewardsWithdrawn(address indexed account, address token, uint256 amount);
    event VoteTokenAuction(address indexed token, uint256 indexed epoch, address auction, uint256 amount);
    event VoteGovernorUpdated(address indexed newVoteGovernor, address indexed newVotingToken);

    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external;

    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external;

    function withdrawVoteTokenRewards() external;

    function withdrawValueTokenRewards() external;

    function updateVoteGovernor(ISPOGGovernor newVoteGovernor) external;
}
