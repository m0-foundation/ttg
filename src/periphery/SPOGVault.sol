// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC20 } from "../interfaces/ImportedInterfaces.sol";
import { ISPOGGovernor } from "../interfaces/ISPOGGovernor.sol";
import { ISPOGVault } from "../interfaces/periphery/ISPOGVault.sol";
import { IVALUE } from "../interfaces/ITokens.sol";

import { SafeERC20 } from "../ImportedContracts.sol";

/// @title SPOGVault
/// @notice Vault will hold SPOG assets shared pro-rata between VALUE holders.
contract SPOGVault is ISPOGVault {
    using SafeERC20 for IERC20;

    /// @notice SPOG governor contract
    address public immutable governor;

    /// @dev epoch => token => account => bool
    mapping(uint256 epoch => mapping(address token => mapping(address account => bool isAlreadyWithdrawn)))
        public alreadyWithdrawn;

    /// @dev epoch => token => amount
    mapping(uint256 epoch => mapping(address token => uint256 amount)) public deposits;

    /// @notice Constructs a new instance of VALUE vault
    /// @param governor_ SPOG governor contract
    constructor(address governor_) {
        governor = governor_;
    }

    /// @notice Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function deposit(uint256 epoch, address token, uint256 amount) external virtual {
        // TODO: should we allow to deposit only for next epoch ? or current and next epoch is good ?
        uint256 currentEpoch = ISPOGGovernor(governor).currentEpoch();

        if (epoch < currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

        deposits[epoch][token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposited(epoch, token, amount);
    }

    /// @notice Withdraw rewards for a 1+ epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    /// @return totalRewards Total rewards withdrawn
    function withdraw(uint256[] memory epochs, address token) external virtual returns (uint256) {
        uint256 length = epochs.length;
        uint256 currentEpoch = ISPOGGovernor(governor).currentEpoch();
        uint256 totalRewards;

        for (uint256 i; i < length; ++i) {
            uint256 epoch = epochs[i];

            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

            totalRewards += _withdraw(epoch, msg.sender, token);
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

        uint256 epochStart = ISPOGGovernor(governor).startOf(epoch);

        // account reward = (account votes weight * shared rewards) / total votes weight
        // TODO: accounting for leftover/debris here, check overflow ranges ?
        uint256 totalVotesWeight = IVALUE(ISPOGGovernor(governor).value()).getPastTotalSupply(epochStart);
        uint256 accountVotesWeight = IVALUE(ISPOGGovernor(governor).value()).getPastVotes(account, epochStart);
        uint256 reward = (deposits[epoch][token] * accountVotesWeight) / totalVotesWeight;

        emit EpochRewardsWithdrawn(epoch, account, token, reward);

        return reward;
    }
}
