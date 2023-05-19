// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

interface IValueVault {
    event EpochRewardsDeposit(uint256 indexed epoch, address indexed token, uint256 amount);
    event EpochRewardsClaim(uint256 indexed epoch, address indexed account, address indexed token, uint256 amount);

    // errors
    error InvalidEpoch(uint256 invalidEpoch, uint256 currentEpoch);
    error EpochWithNoRewards();
    error AlreadyClaimed();

    function depositRewards(uint256 epoch, address token, uint256 amount) external;
    function claimRewards(uint256[] memory epochs, address token) external returns (uint256);
}
