// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "src/interfaces/ISPOGGovernor.sol";
import "src/interfaces/IERC20PricelessAuction.sol";
import "src/interfaces/vaults/IVoteVault.sol";
import "src/periphery/vaults/ValueVault.sol";

/// @title Vault for vote holders to claim their pro rata share of vote inflation and value rewards
contract VoteVault is ValueVault, IVoteVault {
    using SafeERC20 for IERC20;

    /// @notice Auction contract to sell inactive voters inflation rewards
    IERC20PricelessAuction public immutable auctionContract;

    /// @notice Auction count
    uint256 public auctionCount;

    /// @notice Auction per epoch
    mapping(uint256 => address) public auctionForEpoch;

    /// @notice Constructs new instance of vote vault
    constructor(address governor, address _auctionContract) ValueVault(governor) {
        auctionContract = IERC20PricelessAuction(_auctionContract);
    }

    /// @notice Sell inactive voters inflation rewards
    /// @param epochs Epoch to sell tokens from
    /// @return auction Auction address and amount of tokens to sell
    function sellInactiveVoteInflation(uint256[] calldata epochs) external override returns (address, uint256) {
        address token = address(governor.vote());
        uint256 numTokensToSell;

        uint256 length = epochs.length;

        uint256 currentEpoch = governor.currentEpoch();

        address auction = Clones.cloneDeterministic(address(auctionContract), bytes32(auctionCount));
        auctionCount++;

        for (uint256 i; i < length;) {
            uint256 epoch = epochs[i];
            if (epoch >= currentEpoch) revert InvalidEpoch(epoch, currentEpoch);
            if (auctionForEpoch[epoch] != address(0)) revert AuctionAlreadyExists(epoch, auctionForEpoch[epoch]);

            // includes inflation
            uint256 epochStartBlockNumber = governor.startOf(epoch);
            uint256 totalCoinsForEpoch = governor.vote().getPastTotalSupply(epochStartBlockNumber);

            uint256 totalInflation = epochTokenDeposit[token][epoch];

            // vote weights as they were before inflation
            uint256 preInflatedCoinsForEpoch = totalCoinsForEpoch - totalInflation;

            // weights are calculated before inflation
            uint256 activeCoinsForEpoch = governor.epochTotalVotesWeight(epoch);

            uint256 percentageOfTotalSupply = activeCoinsForEpoch * PRECISION_FACTOR / preInflatedCoinsForEpoch;

            uint256 activeCoinsInflation = percentageOfTotalSupply * totalInflation / PRECISION_FACTOR;

            uint256 inactiveCoinsInflation = totalInflation - activeCoinsInflation;

            numTokensToSell += inactiveCoinsInflation;

            auctionForEpoch[epoch] = address(auction);

            unchecked {
                ++i;
            }
        }

        if (numTokensToSell == 0) {
            revert NoTokensToSell();
        }

        IERC20(token).approve(auction, numTokensToSell);
        address paymentToken = address(ISPOG(governor.spog()).cash());
        uint256 duration = governor.votingPeriod();
        IERC20PricelessAuction(auction).initialize(token, paymentToken, duration, numTokensToSell);

        emit VoteTokenAuction(token, epochs, auction, numTokensToSell);

        return (auction, numTokensToSell);
    }

    /// @notice Withdraw rewards for given epochs
    /// @param epochs Epochs to withdraw rewards
    /// @param token Token to withdraw rewards
    /// @return totalRewards Total rewards withdrawn
    function withdraw(uint256[] memory epochs, address token) external virtual override returns (uint256) {
        address valueToken = address(governor.value());
        uint256 currentEpoch = governor.currentEpoch();
        uint256 length = epochs.length;
        uint256 totalRewards;

        for (uint256 i; i < length;) {
            uint256 epoch = epochs[i];
            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);
            if (!governor.isActive(epoch, msg.sender)) revert NotVotedOnAllProposals();

            // TODO: should we allow to withdraw any token or vote and value ?
            RewardsSharingStrategy strategy = (token == valueToken)
                ? RewardsSharingStrategy.ACTIVE_PARTICIPANTS_PRO_RATA
                : RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA;
            totalRewards += _claimRewards(epoch, token, strategy);

            unchecked {
                ++i;
            }
        }
        return totalRewards;
    }
}
