// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISPOGGovernor } from "src/interfaces/ISPOGGovernor.sol";
import { ISPOGVault } from "src/interfaces/periphery/ISPOGVault.sol";

/// @title SPOGVault
/// @notice Vault will hold SPOG assets shared pro-rata between VALUE holders.
contract SPOGVault is ISPOGVault {
    using SafeERC20 for IERC20;

    /// @notice SPOG governor contract
    ISPOGGovernor public immutable override governor;

    /// @dev epoch => token => account => bool
    mapping(uint256 => mapping(address => mapping(address => bool))) public override alreadyWithdrawn;
    /// @dev epoch => token => amount
    mapping(uint256 => mapping(address => uint256)) public override deposits;

    /// @notice Constructs a new instance of VALUE vault
    /// @param _governor SPOG governor contract
    constructor(address _governor) {
        governor = ISPOGGovernor(payable(_governor));
    }

    /// @notice Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function deposit(uint256 epoch, address token, uint256 amount) external virtual override {
        // TODO: should we allow to deposit only for next epoch ? or current and next epoch is good ?
        uint256 currentEpoch = governor.currentEpoch();
        if (epoch < currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

        deposits[epoch][token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposited(epoch, token, amount);
    }

    /// @notice Withdraw rewards for a 1+ epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    /// @return totalRewards Total rewards withdrawn
    function withdraw(uint256[] memory epochs, address token) external virtual override returns (uint256) {
        uint256 length = epochs.length;
        uint256 currentEpoch = governor.currentEpoch();
        uint256 totalRewards;
        for (uint256 i; i < length;) {
            uint256 epoch = epochs[i];
            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

            totalRewards += _withdraw(epoch, msg.sender, token);
            unchecked {
                ++i;
            }
        }

        IERC20(token).safeTransfer(msg.sender, totalRewards);

        return totalRewards;
    }

    /// @notice Withdraw account rewards per epoch
    /// @param epoch The epoch to withdraw rewards for
    /// @param account The account to withdraw rewards for
    /// @param token The token to withdraw rewards for
    /// @return reward The amount of rewards to be withdrawn per epoch
    function _withdraw(uint256 epoch, address account, address token) internal virtual returns (uint256) {
        if (deposits[epoch][token] == 0) revert EpochWithNoRewards();
        if (alreadyWithdrawn[epoch][token][account]) revert AlreadyWithdrawn();

        alreadyWithdrawn[epoch][token][account] = true;

        uint256 epochStart = governor.startOf(epoch);

        // account reward = (account votes weight * shared rewards) / total votes weight
        // TODO: accounting for leftover/debris here, check overflow ranges ?
        uint256 totalVotesWeight = governor.value().getPastTotalSupply(epochStart);
        uint256 accountVotesWeight = governor.value().getPastVotes(account, epochStart);
        uint256 reward = deposits[epoch][token] * accountVotesWeight / totalVotesWeight;

        emit EpochRewardsWithdrawn(epoch, account, token, reward);

        return reward;
    }
}
