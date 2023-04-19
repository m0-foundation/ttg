// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IVault} from "src/interfaces/IVault.sol";

import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault is IVault {
    using SafeERC20 for IERC20;

    ISPOGGovernor public immutable voteGovernor;
    ISPOGGovernor public immutable valueGovernor;

    // address => voting epoch => bool
    mapping(address => mapping(uint256 => bool)) public hasClaimedVoteTokenRewardsForEpoch;
    mapping(address => mapping(uint256 => bool)) public hasClaimedValueTokenRewardsForEpoch;

    // token address => epoch => amount
    mapping(address => mapping(uint256 => uint256)) public epochVotingTokenDeposit;
    mapping(address => mapping(uint256 => uint256)) public epochVotingTokenTotalWithdrawn;

    constructor(ISPOGGovernor _voteGovernor, ISPOGGovernor _valueGovernor) {
        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;
    }

    modifier onlyGovernor() {
        require(msg.sender == address(voteGovernor) || msg.sender == address(valueGovernor), "Vault: Only governor");

        _;
    }

    modifier onlySpog() {
        require(msg.sender == address(voteGovernor.spogAddress()), "Vault: Only spog");

        _;
    }

    /// @dev Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external onlyGovernor {
        epochVotingTokenDeposit[token][epoch] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposit(epoch, token, amount);
    }

    /// @dev Sell unclaimed vote tokens
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external onlySpog {
        address token = address(voteGovernor.votingToken());
        uint256 currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();
        require(epoch < currentVotingPeriodEpoch, "Vault: epoch is not in the past");

        address auction = address(new ERC20PricelessAuction(token, paymentToken, duration, address(this)));
        uint256 unclaimed = epochVotingTokenDeposit[token][epoch] - epochVotingTokenTotalWithdrawn[token][epoch];
        IERC20(token).approve(auction, unclaimed);
        ERC20PricelessAuction(auction).init(unclaimed);

        emit VoteTokenAuction(token, epoch, auction, unclaimed);
    }

    /// @dev Withdraw unsold vote tokens from auction back to vote governor
    /// where they can be sold again next epoch
    function reclaimUnsoldVoteTokens(address auction) public onlySpog {
        address recipient = address(voteGovernor);
        ERC20PricelessAuction(auction).withdraw(recipient);
    }

    /// @dev Withdraw Vote Token Rewards
    function withdrawVoteTokenRewards() external {
        address token = address(voteGovernor.votingToken());
        uint256 currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();

        require(
            !hasClaimedVoteTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch],
            "Vault: vote rewards already withdrawn"
        );
        hasClaimedVoteTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch] = true;

        uint256 numOfProposalsVotedOnEpoch =
            voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, currentVotingPeriodEpoch);

        uint256 totalProposalsEpoch = voteGovernor.epochProposalsCount(currentVotingPeriodEpoch);

        require(
            numOfProposalsVotedOnEpoch == totalProposalsEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = voteGovernor.accountEpochVoteWeight(msg.sender, currentVotingPeriodEpoch);

        // get inflation amount for current epoch plus any coins that were stuck in the governor and deposited in updateStartOfNextVotingPeriod()
        uint256 amountToBeSharedOnProRataBasis = epochVotingTokenDeposit[token][currentVotingPeriodEpoch];

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochVotingTokenSupply(currentVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        epochVotingTokenTotalWithdrawn[token][currentVotingPeriodEpoch] += amountToWithdraw;  
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit VoteTokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    function withdrawValueTokenRewards() external {
        uint256 relevantEpoch = voteGovernor.currentVotingPeriodEpoch() - 1;

        require(
            !hasClaimedValueTokenRewardsForEpoch[msg.sender][relevantEpoch], "Vault: value rewards already withdrawn"
        );
        hasClaimedValueTokenRewardsForEpoch[msg.sender][relevantEpoch] = true;

        uint256 numOfProposalsVotedOnRelevantEpoch =
            voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, relevantEpoch);

        uint256 totalProposalsRelevantEpoch = voteGovernor.epochProposalsCount(relevantEpoch);

        require(
            numOfProposalsVotedOnRelevantEpoch == totalProposalsRelevantEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = voteGovernor.accountEpochVoteWeight(msg.sender, relevantEpoch);

        uint256 valueTokenAmountToBeSharedOnProRataBasis = valueGovernor.epochVotingTokenInflationAmount(relevantEpoch);

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochSumOfVoteWeight(relevantEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * valueTokenAmountToBeSharedOnProRataBasis / 100;

        address token = address(valueGovernor.votingToken());

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit ValueTokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
