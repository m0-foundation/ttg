// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {SPOGGovernorBase} from "src/core/governance/SPOGGovernorBase.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {BaseVault} from "src/periphery/vaults/BaseVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract VoteVault is IVoteVault, BaseVault {
    using SafeERC20 for IERC20;

    IERC20PricelessAuction public immutable auctionContract;

    constructor(SPOGGovernorBase _governor, IERC20PricelessAuction _auctionContract) BaseVault(_governor) {
        auctionContract = _auctionContract;
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to view unclaimed tokens
    function unclaimedVoteTokensForEpoch(uint256 epoch) public view returns (uint256) {
        address token = address(governor.votingToken());
        return epochTokenDeposit[token][epoch] - epochTokenTotalWithdrawn[token][epoch];
    }

    /// @notice Sell inactive voters inflation rewards
    /// @param epoch Epoch to sell tokens from
    /// @param paymentToken Token to accept for payment
    /// @param duration The duration of the auction
    function sellInactiveVoteInflation(uint256 epoch, address paymentToken, uint256 duration) external onlySPOG {
        uint256 currentEpoch = governor.currentEpoch();
        if (epoch >= currentEpoch) revert EpochNotInThePast();

        address token = address(governor.votingToken());
        address auction = Clones.cloneDeterministic(address(auctionContract), bytes32(epoch));

        // includes inflation
        uint256 totalCoinsForEpoch = governor.votingToken().getPastTotalSupply(epochStartBlockNumber[epoch]);

        uint256 totalInflation = epochTokenDeposit[token][epoch];

        // vote weights as they were before inflation
        uint256 preInflatedCoinsForEpoch = totalCoinsForEpoch - totalInflation;

        // weights are calculated before inflation
        uint256 activeCoinsForEpoch = governor.epochSumOfVoteWeight(epoch);

        uint256 passiveCoinsForEpoch = preInflatedCoinsForEpoch - activeCoinsForEpoch;

        uint256 inactiveCoinsInflation = (totalInflation * 100) / preInflatedCoinsForEpoch * passiveCoinsForEpoch / 100;

        // TODO: introduce error
        if (inactiveCoinsInflation == 0) {
            revert();
        }
        IERC20(token).approve(auction, inactiveCoinsInflation);

        IERC20PricelessAuction(auction).initialize(token, paymentToken, duration, address(this), inactiveCoinsInflation);

        emit VoteTokenAuction(token, epoch, auction, inactiveCoinsInflation);
    }

    /// @dev Claim Vote token inflation rewards by vote holders
    /// @param epochs Epochs to claim rewards for
    function claimVoteTokenRewards(uint256[] memory epochs) external {
        uint256 currentEpoch = governor.currentEpoch();
        uint256 length = epochs.length;
        address rewardToken = address(governor.votingToken());

        for (uint256 i; i < length;) {
            if (epochs[i] > currentEpoch) {
                revert InvalidEpoch(epochs[i], currentEpoch);
            }

            _checkParticipation(epochs[i]);

            // vote holders claim their epoch vote rewards
            _withdrawTokenRewards(epochs[i], rewardToken, RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Claim Value token inflation rewards by vote holders
    /// @param epochs Epochs to claim value rewards for
    function claimValueTokenRewards(uint256[] memory epochs) external {
        uint256 currentEpoch = governor.currentEpoch();
        uint256 length = epochs.length;
        address rewardToken = address(ISPOG(governor.spogAddress()).valueGovernor().votingToken());

        for (uint256 i; i < length;) {
            if (epochs[i] >= currentEpoch) {
                revert InvalidEpoch(epochs[i], currentEpoch);
            }

            _checkParticipation(epochs[i]);

            // vote holders claim their epoch value rewards
            _withdrawTokenRewards(epochs[i], rewardToken, RewardsSharingStrategy.ACTIVE_PARTICIPANTS_PRO_RATA);

            unchecked {
                ++i;
            }
        }
    }

    // @notice Update vote governor after `RESET` was executed
    // @param newGovernor New vote governor
    function updateGovernor(SPOGGovernorBase newGovernor) external onlySPOG {
        emit VoteGovernorUpdated(address(newGovernor), address(newGovernor.votingToken()));

        governor = newGovernor;
    }

    // TODO potentially modifier ?
    function _checkParticipation(uint256 epoch) private view {
        // withdraw rewards only if voted on all proposals in epoch
        uint256 numOfProposalsVotedOnEpoch = governor.accountEpochNumProposalsVotedOn(msg.sender, epoch);
        uint256 totalProposalsEpoch = governor.epochProposalsCount(epoch);
        if (numOfProposalsVotedOnEpoch != totalProposalsEpoch) revert NotVotedOnAllProposals();
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
