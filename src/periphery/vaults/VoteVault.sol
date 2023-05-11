// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {BaseVault} from "src/periphery/vaults/BaseVault.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import "forge-std/console.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract VoteVault is IVoteVault, BaseVault {
    using SafeERC20 for IERC20;

    IERC20PricelessAuction public immutable auctionContract;

    //TODO: not changing require into error revert, this modifier should potentially be gone
    modifier onlySPOG() {
        require(msg.sender == address(governor.spogAddress()), "Vault: Only spog");
        _;
    }

    modifier onlyActive(uint256 epoch) {
        uint256 numVotedOn = governor.accountEpochNumProposalsVotedOn(msg.sender, epoch);
        uint256 numProposals = governor.epochProposalsCount(epoch);
        if (numVotedOn != numProposals) revert NotVotedOnAllProposals();
        _;
    }

    constructor(ISPOGGovernor _governor, IERC20PricelessAuction _auctionContract) BaseVault(_governor) {
        auctionContract = _auctionContract;
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to view unclaimed tokens
    function auctionableVoteRewards(uint256 epoch) public view override returns (uint256) {
        address token = address(governor.votingToken());
        return epochTokenDeposit[token][epoch] - epochTokenTotalWithdrawn[token][epoch];
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to sell tokens from
    /// @param paymentToken Token to accept for payment
    /// @param duration The duration of the auction
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration)
        external
        override
        onlySPOG
    {
        if (epoch >= governor.currentEpoch()) revert EpochIsNotInThePast();

        address token = address(governor.votingToken());
        address auction = Clones.cloneDeterministic(address(auctionContract), bytes32(epoch));

        uint256 unclaimed = auctionableVoteRewards(epoch);
        // TODO: introduce error
        if (unclaimed == 0) {
            return;
        }
        IERC20(token).approve(auction, unclaimed);

        IERC20PricelessAuction(auction).initialize(token, paymentToken, duration, address(this), unclaimed);

        emit VoteTokenAuction(token, epoch, auction, unclaimed);
    }

    /// @dev Claim Vote token inflation rewards by vote holders
    function claimVoteRewards(uint256 epoch) external override onlyActive(epoch) {
        console.log("Step 1");
        if (epoch > governor.currentEpoch()) revert EpochIsNotInThePast();
        address rewardToken = address(governor.votingToken());
        console.log("Step 2");

        // vote holders claim their epoch vote rewards
        _claimRewards(epoch, rewardToken, RewardsSharingStrategy.ALL_PARTICIPANTS_PRO_RATA);
    }

    /// @dev Claim Value token inflation rewards by vote holders
    function claimValueRewards(uint256 epoch) external override onlyActive(epoch) {
        if (epoch >= governor.currentEpoch()) revert EpochIsNotInThePast();
        address valueToken = address(ISPOG(governor.spogAddress()).valueGovernor().votingToken());

        // vote holders claim their epoch value rewards
        _claimRewards(epoch, valueToken, RewardsSharingStrategy.ACTIVE_PARTICIPANTS_PRO_RATA);
    }

    // @notice Update vote governor after `RESET` was executed
    // @param newGovernor New vote governor
    function updateGovernor(ISPOGGovernor newGovernor) external override onlySPOG {
        emit VoteGovernorUpdated(address(newGovernor), address(newGovernor.votingToken()));

        governor = newGovernor;
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
