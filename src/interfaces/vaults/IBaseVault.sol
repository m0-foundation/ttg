// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

interface IBaseVault {
    event EpochRewardsDeposit(uint256 indexed epoch, address indexed token, uint256 amount);
    event TokenRewardsWithdrawn(address indexed account, address indexed token, uint256 amount);

    // SPOG-triggered functions
    function depositRewards(uint256 epoch, address token, uint256 amount) external;
}
