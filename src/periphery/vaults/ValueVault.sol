// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/ISPOGGovernor.sol";
import "src/interfaces/vaults/ISPOGVault.sol";
import "src/tokens/InflationaryVotes.sol";

/// @title Vault
/// @notice contract that will hold inflation rewards and the SPOG assets.
contract ValueVault is ISPOGVault {
    using SafeERC20 for IERC20;

    enum RewardsSharingStrategy
    // default strategy, share rewards between all governance participants
    {
        ALL_PARTICIPANTS_PRO_RATA,
        // share rewards between only participants who were active in epoch
        ACTIVE_PARTICIPANTS_PRO_RATA
    }

    /// @notice governor contract
    ISPOGGovernor public immutable governor;

    uint256 public constant PRECISION_FACTOR = 1e18;

    // address => epoch => token => bool
    mapping(address => mapping(uint256 => mapping(address => bool))) public hasClaimedTokenRewardsForEpoch;

    // token address => epoch => amount
    mapping(address => mapping(uint256 => uint256)) public epochTokenDeposit;
    mapping(address => mapping(uint256 => uint256)) public epochTokenTotalWithdrawn;

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

        epochTokenDeposit[token][epoch] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposit(epoch, token, amount);
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

            totalRewards += _claimRewards(epoch, token, RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA);
            unchecked {
                ++i;
            }
        }
        return totalRewards;
    }

    /// @dev Withdraw rewards per epoch base on strategy
    /// @param epoch The epoch to claim rewards for
    function _claimRewards(uint256 epoch, address token, RewardsSharingStrategy strategy)
        internal
        virtual
        returns (uint256)
    {
        if (epochTokenDeposit[token][epoch] == 0) revert EpochWithNoRewards();
        if (hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token]) revert AlreadyClaimed();

        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token] = true;

        uint256 epochStart = governor.startOf(epoch);
        // if vote holders claim value inflation, use special case - total votes weight of only active participants
        // otherwise use standard total supply votes weight
        uint256 totalVotesWeight;
        if (strategy == RewardsSharingStrategy.ACTIVE_PARTICIPANTS_PRO_RATA) {
            totalVotesWeight = governor.epochTotalVotesWeight(epoch);
        } else {
            // do not take into account rewards inflation for current epoch
            // TODO: fix for one governor!!!!!
            uint256 inflation = epochTokenDeposit[address(governor.vote())][epoch];
            totalVotesWeight = governor.vote().getPastTotalSupply(epochStart) - inflation;
        }

        // account reward = (account votes weight * shared rewards) / total votes weight
        uint256 accountVotesWeight = governor.vote().getPastVotes(msg.sender, epochStart);
        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][epoch];

        uint256 percentageOfTotalSupply = accountVotesWeight * PRECISION_FACTOR / totalVotesWeight;
        // TODO: simplification: amountToWithdraw = accountVotesWeight * amountToBeSharedOnProRataBasis / totalVotesWeight; ?
        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / PRECISION_FACTOR;

        // withdraw rewards from vault
        epochTokenTotalWithdrawn[token][epoch] += amountToWithdraw;
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit EpochRewardsClaim(epoch, msg.sender, token, amountToWithdraw);

        return amountToWithdraw;
    }
}
