// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {BaseVault} from "src/periphery/vaults/BaseVault.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract ValueVault is IValueVault, BaseVault {
    using SafeERC20 for IERC20;

    constructor(ISPOGGovernor _governor) BaseVault(_governor) {}

    /// @dev Withdraw rewards for multiple epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function claimRewards(uint256[] memory epochs, address token) external override {
        uint256 length = epochs.length;
        for (uint256 i; i < length;) {
            claimRewards(epochs[i], token);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Withdraw rewards for a single epoch for a token
    /// @param epoch Epoch to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function claimRewards(uint256 epoch, address token) public override {
        if (epoch > governor.currentEpoch()) revert EpochIsNotInThePast();
        _claimRewards(epoch, token, RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
