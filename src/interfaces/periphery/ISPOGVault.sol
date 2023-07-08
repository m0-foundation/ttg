// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "src/interfaces/ISPOGGovernor.sol";

interface ISPOGVault {
    // events
    event EpochRewardsDeposited(uint256 indexed epoch, address indexed token, uint256 amount);
    event EpochRewardsWithdrawn(uint256 indexed epoch, address indexed account, address indexed token, uint256 amount);

    // errors
    error InvalidEpoch(uint256 invalidEpoch, uint256 currentEpoch);
    error EpochWithNoRewards();
    error AlreadyWithdrawn();

    function governor() external returns (ISPOGGovernor);
    function deposit(uint256 epoch, address token, uint256 amount) external;
    function withdraw(uint256[] memory epochs, address token) external returns (uint256);
    function deposits(uint256 epoch, address token) external view returns (uint256);
    function alreadyWithdrawn(uint256 epoch, address token, address account) external view returns (bool);
}
