// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault {
    using SafeERC20 for IERC20;

    ISPOGGovernor public immutable govSpogVote;
    ISPOGGovernor public immutable govSpogValue;

    event Withdraw(address indexed account, address token, uint256 amount);
    event VoteTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);
    event ValueTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);

    // address => voting epoch => bool
    mapping(address => mapping(uint256 => bool)) public hasClaimedVoteTokenRewardsForEpoch;
    mapping(address => mapping(uint256 => bool)) public hasClaimedValueTokenRewardsForEpoch;

    constructor(ISPOGGovernor _govSpogVote, ISPOGGovernor _govSpogValue) {
        govSpogVote = _govSpogVote;
        govSpogValue = _govSpogValue;
    }

    /// @dev Withdraw Vote Token Rewards
    function withdrawVoteTokenRewards() external {
        uint256 currentVotingPeriodEpoch = govSpogVote.currentVotingPeriodEpoch();

        require(
            !hasClaimedVoteTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch],
            "Vault: vote rewards already withdrawn"
        );
        hasClaimedVoteTokenRewardsForEpoch[msg.sender][currentVotingPeriodEpoch] = true;

        uint256 numOfProposalsVotedOnEpoch =
            govSpogVote.accountEpochNumProposalsVotedOn(msg.sender, currentVotingPeriodEpoch);

        uint256 totalProposalsEpoch = govSpogVote.epochProposalsCount(currentVotingPeriodEpoch);

        require(
            numOfProposalsVotedOnEpoch == totalProposalsEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = govSpogVote.accountEpochVoteWeight(msg.sender, currentVotingPeriodEpoch);

        uint256 amountToBeSharedOnProRataBasis = govSpogVote.epochVotingTokenInflationAmount(currentVotingPeriodEpoch);

        uint256 totalVotingTokenSupplyApplicable = govSpogVote.epochVotingTokenSupply(currentVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        address token = address(govSpogVote.votingToken());

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit VoteTokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    function withdrawValueTokenRewards() external {
        uint256 relevantEpoch = govSpogVote.currentVotingPeriodEpoch() - 1;

        require(
            !hasClaimedValueTokenRewardsForEpoch[msg.sender][relevantEpoch], "Vault: value rewards already withdrawn"
        );
        hasClaimedValueTokenRewardsForEpoch[msg.sender][relevantEpoch] = true;

        uint256 numOfProposalsVotedOnRelevantEpoch =
            govSpogVote.accountEpochNumProposalsVotedOn(msg.sender, relevantEpoch);

        uint256 totalProposalsRelevantEpoch = govSpogVote.epochProposalsCount(relevantEpoch);

        require(
            numOfProposalsVotedOnRelevantEpoch == totalProposalsRelevantEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        uint256 accountVotesWeight = govSpogVote.accountEpochVoteWeight(msg.sender, relevantEpoch);

        uint256 valueTokenAmountToBeSharedOnProRataBasis = govSpogValue.epochVotingTokenInflationAmount(relevantEpoch);

        uint256 totalVotingTokenSupplyApplicable = govSpogVote.epochSumOfVoteWeight(relevantEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * valueTokenAmountToBeSharedOnProRataBasis / 100;

        address token = address(govSpogValue.votingToken());

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit ValueTokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
