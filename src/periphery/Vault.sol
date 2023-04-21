// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";
import {IVault} from "src/interfaces/IVault.sol";

import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault is IVault {
    using SafeERC20 for IERC20;

    ISPOGGovernor public immutable voteGovernor;
    ISPOGGovernor public immutable valueGovernor;

    // address => epoch => token => bool
    mapping(address => mapping(uint256 => mapping(address => bool))) public hasClaimedTokenRewardsForEpoch;

    // token address => epoch => amount
    mapping(address => mapping(uint256 => uint256)) public epochTokenDeposit;
    mapping(address => mapping(uint256 => uint256)) public epochTokenTotalWithdrawn;

    constructor(ISPOGGovernor _voteGovernor, ISPOGGovernor _valueGovernor) {
        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;
    }

    modifier onlyAllowed() {
        require(
            msg.sender == address(voteGovernor.spogAddress()) || msg.sender == address(voteGovernor)
                || msg.sender == address(valueGovernor),
            "Vault: Only allowed"
        );

        _;
    }

    modifier onlySpog() {
        require(msg.sender == address(voteGovernor.spogAddress()), "Vault: Only spog");

        _;
    }

    /// @notice Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external onlyAllowed {
        epochTokenDeposit[token][epoch] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposit(epoch, token, amount);
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to view unclaimed tokens
    function unclaimedVoteTokensForEpoch(uint256 epoch) public view returns (uint256) {
        address token = address(voteGovernor.votingToken());
        return epochTokenDeposit[token][epoch] - epochTokenTotalWithdrawn[token][epoch];
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to sell tokens from
    /// @param paymentToken Token to accept for payment
    /// @param duration The duration of the auction
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external onlySpog {
        uint256 currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();
        require(epoch < currentVotingPeriodEpoch, "Vault: epoch is not in the past");

        address token = address(voteGovernor.votingToken());
        address auction = address(new ERC20PricelessAuction(token, paymentToken, duration, address(this)));

        uint256 unclaimed = unclaimedVoteTokensForEpoch(epoch);
        IERC20(token).approve(auction, unclaimed);

        ERC20PricelessAuction(auction).init(unclaimed);

        emit VoteTokenAuction(token, epoch, auction, unclaimed);
    }

    /// @dev Withdraw Vote Token Rewards
    function withdrawVoteTokenRewards() external {
        address token = address(voteGovernor.votingToken());

        uint256 currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();

        require(
            !hasClaimedTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch][token],
            "Vault: vote rewards already withdrawn"
        );
        hasClaimedTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch][token] = true;

        uint256 numOfProposalsVotedOnEpoch =
            voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, currentVotingPeriodEpoch);

        uint256 totalProposalsEpoch = voteGovernor.epochProposalsCount(currentVotingPeriodEpoch);

        require(
            numOfProposalsVotedOnEpoch == totalProposalsEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = voteGovernor.accountEpochVoteWeight(msg.sender, currentVotingPeriodEpoch);

        // get inflation amount for current epoch plus any coins that were stuck in the governor and deposited in updateStartOfNextVotingPeriod()
        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][currentVotingPeriodEpoch];

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochVotingTokenSupply(currentVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        epochTokenTotalWithdrawn[token][currentVotingPeriodEpoch] += amountToWithdraw;
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    function withdrawValueTokenRewards() external {
        address token = address(valueGovernor.votingToken());

        uint256 relevantEpoch = voteGovernor.currentVotingPeriodEpoch() - 1;

        require(
            !hasClaimedTokenRewardsForEpoch[msg.sender][relevantEpoch][token], "Vault: value rewards already withdrawn"
        );
        hasClaimedTokenRewardsForEpoch[msg.sender][relevantEpoch][token] = true;

        uint256 numOfProposalsVotedOnRelevantEpoch =
            voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, relevantEpoch);

        uint256 totalProposalsRelevantEpoch = voteGovernor.epochProposalsCount(relevantEpoch);

        require(
            numOfProposalsVotedOnRelevantEpoch == totalProposalsRelevantEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = voteGovernor.accountEpochVoteWeight(msg.sender, relevantEpoch);

        uint256 valueTokenAmountToBeSharedOnProRataBasis = epochTokenDeposit[token][relevantEpoch];

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochSumOfVoteWeight(relevantEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * valueTokenAmountToBeSharedOnProRataBasis / 100;

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    function withdrawRewardsForValueHolders(uint256 epoch, address token) external {
        require(epoch < voteGovernor.currentVotingPeriodEpoch(), "Vault: epoch is not in the past");
        require(epochTokenDeposit[token][epoch] > 0, "Vault: no rewards to withdraw");
        require(!hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token], "Vault: rewards already withdrawn");

        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token] = true;

        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][epoch];

        uint256 epochStartBlockNumber = valueGovernor.epochStartBlockNumber(epoch);

        uint256 totalValueTokenSupplyApplicable =
            ISPOGVotes(valueGovernor.votingToken()).getPastTotalSupply(epochStartBlockNumber);

        uint256 accountBalanceAtEpochStart = valueGovernor.getVotes(msg.sender, epochStartBlockNumber);

        uint256 percentageOfTotalSupply = accountBalanceAtEpochStart * 100 / totalValueTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
