// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {IVault} from "src/interfaces/IVault.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault is IVault {
    using SafeERC20 for IERC20;

    ISPOGGovernor public immutable voteGovernor;
    ISPOGGovernor public immutable valueGovernor;

    // address => voting epoch => bool
    mapping(address => mapping(uint256 => bool)) public hasClaimedVoteTokenRewardsForEpoch;
    mapping(address => mapping(uint256 => bool)) public hasClaimedValueTokenRewardsForEpoch;

    constructor(ISPOGGovernor _voteGovernor, ISPOGGovernor _valueGovernor) {
        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;
    }

    /// @dev Withdraw Vote Token Rewards
    function withdrawVoteTokenRewards() external {
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

        uint256 amountToBeSharedOnProRataBasis = voteGovernor.epochVotingTokenInflationAmount(currentVotingPeriodEpoch);

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochVotingTokenSupply(currentVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        address token = address(voteGovernor.votingToken());

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

    function sellERC20(address token, uint256 amount) external {
        // IERC20(token).safeTransfer(msg.sender, amount);
    }


    fallback() external {
        revert("Vault: non-existent function");
    }
}
