// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/ISPOGGovernor.sol";
import "src/interfaces/periphery/ISPOGVault.sol";

/// @title Vault
/// @notice contract that will hold inflation rewards and the SPOG assets.
contract SPOGVault is ISPOGVault {
    using SafeERC20 for IERC20;

    /// @notice governor contract
    ISPOGGovernor public immutable governor;

    // uint256 public constant PRECISION_FACTOR = 1e18;

    // epoch => token => account => bool
    mapping(uint256 => mapping(address => mapping(address => bool))) public hasClaimedRewards;
    // epoch => token => amount
    mapping(uint256 => mapping(address => uint256)) public deposits;
    // mapping(address => mapping(uint256 => uint256)) public epochTokenTotalWithdrawn;

    /// @notice Constructs new instance of value vault
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

    /// @dev Withdraw rewards for a 1+ epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function withdraw(uint256[] memory epochs, address token) external virtual override returns (uint256) {
        uint256 length = epochs.length;
        uint256 currentEpoch = governor.currentEpoch();
        uint256 totalRewards;
        for (uint256 i; i < length;) {
            uint256 epoch = epochs[i];
            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

            totalRewards += _claimRewards(epoch, msg.sender, token);
            unchecked {
                ++i;
            }
        }

        IERC20(token).safeTransfer(msg.sender, totalRewards);

        return totalRewards;
    }

    /// @dev Withdraw rewards per epoch base on strategy
    /// @param epoch The epoch to claim rewards for
    function _claimRewards(uint256 epoch, address account, address token) internal virtual returns (uint256) {
        if (deposits[epoch][token] == 0) revert EpochWithNoRewards();
        if (hasClaimedRewards[epoch][token][account]) revert AlreadyClaimed();

        hasClaimedRewards[epoch][token][account] = true;

        uint256 epochStart = governor.startOf(epoch);
        uint256 totalVotesWeight = governor.value().getPastTotalSupply(epochStart);

        // account reward = (account votes weight * shared rewards) / total votes weight
        uint256 accountVotesWeight = governor.value().getPastVotes(account, epochStart);
        uint256 reward = deposits[epoch][token] * accountVotesWeight / totalVotesWeight;

        // withdraw rewards from vault
        // epochTokenTotalWithdrawn[token][epoch] += reward;

        emit EpochRewardsClaimed(epoch, account, token, reward);

        return reward;
    }
}
