// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {ISPOG} from "src/interfaces/ISPOG.sol";
import {DualGovernor} from "src/core/governor/DualGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";
import {IVoteToken} from "src/interfaces/tokens/IVoteToken.sol";
import {IValueVault} from "src/interfaces/vaults/IValueVault.sol";
import {ValueVault} from "src/periphery/vaults/ValueVault.sol";

import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract VoteVault is IVoteVault, ValueVault {
    using SafeERC20 for IERC20;

    IERC20PricelessAuction public immutable auctionContract;

    //TODO: not changing require into error revert, this modifier should potentially be gone
    modifier onlySPOG() {
        require(msg.sender == address(governor.spog()), "Vault: Only spog");
        _;
    }

    constructor(DualGovernor _governor, IERC20PricelessAuction _auctionContract) ValueVault(_governor) {
        auctionContract = _auctionContract;
    }

    /// @notice Sell inactive voters inflation rewards
    /// @param epoch Epoch to sell tokens from
    /// @param paymentToken Token to accept for payment
    /// @param duration The duration of the auction
    function sellInactiveVoteInflation(uint256 epoch, address paymentToken, uint256 duration)
        external
        override
        onlySPOG
    {
        if (epoch >= governor.currentEpoch()) revert InvalidEpoch(epoch, governor.currentEpoch());

        // TODO: fix that!!!
        address token = address(governor.vote());
        address auction = Clones.cloneDeterministic(address(auctionContract), bytes32(epoch));

        // includes inflation
        uint256 totalCoinsForEpoch = governor.vote().getPastTotalSupply(epochStartBlockNumber[epoch]);

        uint256 totalInflation = epochTokenDeposit[token][epoch];

        // vote weights as they were before inflation
        uint256 preInflatedCoinsForEpoch = totalCoinsForEpoch - totalInflation;

        // weights are calculated before inflation
        uint256 activeCoinsForEpoch = governor.epochSumOfVoteWeight(epoch);

        uint256 activeCoinsInflation = totalInflation * activeCoinsForEpoch / preInflatedCoinsForEpoch;

        uint256 inactiveCoinsInflation = totalInflation - activeCoinsInflation;

        if (inactiveCoinsInflation == 0) {
            revert NoTokensToSell();
        }

        IERC20(token).approve(auction, inactiveCoinsInflation);

        IERC20PricelessAuction(auction).initialize(token, paymentToken, duration, inactiveCoinsInflation);

        emit VoteTokenAuction(token, epoch, auction, inactiveCoinsInflation);
    }

    function claimRewards(uint256[] memory epochs, address token)
        external
        virtual
        override(IValueVault, ValueVault)
        returns (uint256)
    {
        // TODO: fix here as well when governor is one
        address valueToken = IVoteToken(address(governor.vote())).valueToken();
        uint256 currentEpoch = governor.currentEpoch();
        uint256 length = epochs.length;
        uint256 totalRewards;

        for (uint256 i; i < length;) {
            uint256 epoch = epochs[i];
            if (epoch > currentEpoch) revert InvalidEpoch(epoch, currentEpoch);

            if (!_isActive(msg.sender, epoch)) revert NotVotedOnAllProposals();

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

    // @notice Update vote governor after `RESET` was executed
    // @param newGovernor New vote governor
    function updateGovernor(DualGovernor newGovernor) external onlySPOG {
        // TODO: fix here as well when governor is one
        emit VoteGovernorUpdated(address(newGovernor), address(newGovernor.vote()));

        governor = newGovernor;
    }

    function _isActive(address account, uint256 epoch) internal virtual returns (bool) {
        uint256 numVotedOn = governor.accountEpochNumProposalsVotedOn(account, epoch);
        uint256 numProposals = governor.epochProposalsCount(epoch);
        return numVotedOn == numProposals;
    }
}
