// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {BaseVault} from "src/periphery/vaults/BaseVault.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract ValueVault is IValueVault, BaseVault {
    using SafeERC20 for IERC20;

    constructor(SPOGGovernorBase _governor) BaseVault(_governor) {}

    /// @dev Withdraw rewards for a 1+ epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function withdrawRewards(uint256[] memory epochs, address token) public {
        uint256 length = epochs.length;
        uint256 currentEpoch = governor.currentEpoch();
        for (uint256 i; i < length;) {
            if (epochs[i] >= currentEpoch) {
                revert InvalidEpoch(epochs[i], currentEpoch);
            }

            _withdrawTokenRewards(epochs[i], token, RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA);
            unchecked {
                ++i;
            }
        }
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
