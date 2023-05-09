// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

/// @title Vault
/// @notice contract that will hold inflation rewards and the SPOG assets.
abstract contract VaultBase
    using SafeERC20 for IERC20;

    enum RewardsSharingStrategy
    // default strategy, share rewards between all governance participants
    {
        ALL_PARTICIPANTS_PRO_RATA,
        // share rewards between only participants who were active in epoch
        ACTIVE_PARTICIPANTS_PRO_RATA
    }

    ISPOGGovernor public governor;

    // address => epoch => token => bool
    mapping(address => mapping(uint256 => mapping(address => bool))) public hasClaimedTokenRewardsForEpoch;

    // token address => epoch => amount
    mapping(address => mapping(uint256 => uint256)) public epochTokenDeposit;
    mapping(address => mapping(uint256 => uint256)) public epochTokenTotalWithdrawn;

    // start block numbers for epochs with rewards
    mapping(uint256 => uint256) public epochStartBlockNumber;

    constructor(ISPOGGovernor _governor) {
        governor = _governor;
    }

    modifier onlySPOG() {
        require(msg.sender == address(governor.spogAddress()), "Vault: Only spog");

        _;
    }

    /// @notice Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function depositRewards(uint256 epoch, address token, uint256 amount) external onlySPOG {
        // TODO: should we allow to deposit only for next epoch ? or current and next epoch is good ?
        require(epoch >= governor.currentEpoch(), "Vault: epoch is not in the future");

        // save start block of epoch, our governance allows to change voting period
        epochStartBlockNumber[epoch] = governor.startOfEpoch(epoch);
        epochTokenDeposit[token][epoch] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // emit EpochRewardsDeposit(epoch, token, amount);
    }

    /// @dev Withdraw Vote and Value token rewards
    function _withdrawTokenRewards(uint256 epoch, address token, RewardsSharingStrategy strategy) internal virtual {
        require(epochTokenDeposit[token][epoch] > 0, "Vault: no rewards to withdraw");
        require(!hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token], "Vault: rewards already withdrawn");
        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token] = true;

        uint256 epochStart = epochStartBlockNumber[epoch];
        // if vote holders claim value inflation, use special case - total votes weight of only active participants
        // otherwise use standard total supply votes weight
        uint256 totalVotesWeight;
        if (strategy == RewardsSharingStrategy.ACTIVE_PARTICIPANTS_PRO_RATA) {
            totalVotesWeight = governor.epochSumOfVoteWeight(epoch);
        } else {
            // do not take into account rewards inflation for current epoch
            uint256 inflation = epochTokenDeposit[address(governor.votingToken())][epoch];
            totalVotesWeight = ISPOGVotes(governor.votingToken()).getPastTotalSupply(epochStart) - inflation;
        }

        // account reward = (account votes weight * shared rewards) / total votes weight
        uint256 accountVotesWeight = ISPOGVotes(governor.votingToken()).getPastVotes(msg.sender, epochStart);
        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][epoch];
        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotesWeight;
        // TODO: simplification: amountToWithdraw = accountVotesWeight * amountToBeSharedOnProRataBasis / totalVotesWeight; ?
        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        // withdraw rewards from vault
        epochTokenTotalWithdrawn[token][epoch] += amountToWithdraw;
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        // emit TokenRewardsWithdrawn(msg.sender, rewardToken, amountToWithdraw);
    }
}
