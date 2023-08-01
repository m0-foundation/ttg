// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC20 } from "../ImportedInterfaces.sol";
import { IVault } from "./IVault.sol";
import { IVALUE } from "../tokens/ITokens.sol";

import { SafeERC20 } from "../ImportedContracts.sol";
import { PureEpochs } from "../pureEpochs/PureEpochs.sol";

/// @title Vault
/// @notice Vault will hold SPOG assets shared pro-rata between VALUE holders.
contract Vault is IVault {
    using SafeERC20 for IERC20;

    /// @notice SPOG value token contract
    address public immutable value;

    /// @dev epoch => token => account => bool
    mapping(uint256 epoch => mapping(address token => mapping(address account => bool isAlreadyWithdrawn)))
        public alreadyWithdrawn;

    /// @dev epoch => token => amount
    mapping(uint256 epoch => mapping(address token => uint256 amount)) public deposits;

    /// @notice Constructs a new instance of VALUE vault
    /// @param value_ SPOG value token contract
    constructor(address value_) {
        value = value_;
    }

    /// @notice Deposit assets for the epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of tokens to deposit
    function deposit(uint256 epoch, address token, uint256 amount) external virtual {
        // TODO: should we allow to deposit only for next epoch ? or current and next epoch is good ?
        uint256 currentEpoch = PureEpochs.currentEpoch();

        if (epoch < currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

        deposits[epoch][token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochAssetsDeposited(epoch, token, amount);
    }

    /// @notice Withdraw assets for a 1+ epochs
    /// @param epochs Epochs to withdraw assets for
    /// @param token Assets to withdraw
    /// @return Total amount of assets to be withdrawn
    function withdraw(uint256[] memory epochs, address token) external virtual returns (uint256) {
        uint256 length = epochs.length;
        uint256 currentEpoch = PureEpochs.currentEpoch();
        uint256 totalAmount;

        for (uint256 i; i < length; ++i) {
            uint256 epoch = epochs[i];

            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

            totalAmount += _withdraw(epoch, msg.sender, token);
        }

        IERC20(token).safeTransfer(msg.sender, totalAmount);

        return totalAmount;
    }

    /// @notice Withdraw assets per epoch
    /// @param epoch The epoch to withdraw assets for
    /// @param account The account to withdraw assets for
    /// @param token The assets to withdraw
    /// @return The amount of assets to be withdrawn per epoch
    function _withdraw(uint256 epoch, address account, address token) internal virtual returns (uint256) {
        if (deposits[epoch][token] == 0) revert EpochWithNoAssets();
        if (alreadyWithdrawn[epoch][token][account]) revert AlreadyWithdrawn();

        alreadyWithdrawn[epoch][token][account] = true;

        uint256 epochStart = PureEpochs.getBlockNumberOfEpochStart(epoch);

        // amount to withdraw = (account votes weight * shared assets) / total votes weight
        // TODO: accounting for leftover/debris here, check overflow ranges ?
        uint256 totalVotesWeight = IVALUE(value).getPastTotalSupply(epochStart);
        uint256 accountVotesWeight = IVALUE(value).getPastVotes(account, epochStart);
        uint256 amount = (deposits[epoch][token] * accountVotesWeight) / totalVotesWeight;

        emit EpochAssetsWithdrawn(epoch, account, token, amount);

        return amount;
    }
}
