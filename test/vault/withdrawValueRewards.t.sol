// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";

contract Vault_WithdrawValueTokenRewards is Vault_IntegratedWithSPOG {
    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // calculate value token inflation rewards for voter
    function calculateValueTokenInflationRewardsForVoter(
        address voter,
        uint256 proposalId,
        uint256 amountToBeSharedOnProRataBasis
    ) private view returns (uint256) {
        uint256 relevantVotingPeriodEpoch = governor.currentEpoch() - 1;

        uint256 accountVotingTokenBalance = governor.getVotes(voter, governor.proposalSnapshot(proposalId));

        uint256 totalVotingTokenSupplyApplicable = governor.epochTotalVotesWeight(relevantVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotingTokenBalance * 100 / totalVotingTokenSupplyApplicable;

        uint256 inflationRewards = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        return inflationRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UsersCanClaimValueTokenInflationAfterVotingOnInAllProposals() public {
        // start balance of value for voteVault should be 0
        uint256 valueInitialBalanceForVault = value.balanceOf(address(voteVault));
        assertEq(valueInitialBalanceForVault, 0, "voteVault should have 0 value balance");

        // set up proposals and inflate supply
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        uint256 valueBalanceForVaultAfterProposals = value.balanceOf(address(voteVault));
        assertEq(
            valueBalanceForVaultAfterProposals,
            spog.valueFixedInflation(),
            "voteVault should have value inflation rewards balance"
        );

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 epochInflation = spog.valueFixedInflation();

        // alice votes on proposal 1, 2 and 3
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        uint256 valueBalanceForVaultForEpochOne = value.balanceOf(address(voteVault));
        assertEq(
            valueBalanceForVaultForEpochOne, valueBalanceForVaultAfterProposals, "voting does not affect inflation"
        );

        // bob votes on proposal 1, 2 and 3
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        governor.castVote(proposalId2, noVote);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // carol doen't vote in all proposals
        vm.startPrank(carol);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // start epoch 2
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 aliceValueBalanceBefore = value.balanceOf(alice);
        uint256 bobValueBalanceBefore = value.balanceOf(bob);

        uint256 relevantEpoch = governor.currentEpoch() - 1;
        uint256[] memory epochsToClaimRewards = new uint256[](1);
        epochsToClaimRewards[0] = relevantEpoch;

        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(value)),
            "Alice should not have claimed value token rewards"
        );
        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(value)),
            "Bob should not have claimed value token rewards"
        );

        // alice and bob withdraw their value token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        voteVault.withdraw(epochsToClaimRewards, address(value));
        vm.stopPrank();

        vm.startPrank(bob);
        voteVault.withdraw(epochsToClaimRewards, address(value));
        vm.stopPrank();

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(value)),
            "Alice should have claimed value token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(value)),
            "Bob should have claimed value token rewards"
        );

        // alice and bobs should have received value token inflationary rewards from epoch 1 in epoch 2
        assertEq(
            value.balanceOf(alice),
            calculateValueTokenInflationRewardsForVoter(alice, proposalId, epochInflation) + aliceValueBalanceBefore,
            "Alice has unexpected balance"
        );
        assertEq(
            value.balanceOf(bob),
            calculateValueTokenInflationRewardsForVoter(bob, proposalId, epochInflation) + bobValueBalanceBefore,
            "Bob has unexpected balance"
        );

        // alice and bob have received the same amount of inflation rewards so their balance are the same
        assertEq(value.balanceOf(alice), value.balanceOf(bob), "Alice and Bob should have same vote balance");

        vm.startPrank(carol);

        uint256 carolValueBalanceBefore = value.balanceOf(carol);

        // carol fails to withdraw value token rewards because she has not voted in all proposals
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.withdraw(epochsToClaimRewards, address(value));
        vm.stopPrank();

        // carol remains with the same balance
        assertEq(value.balanceOf(carol), carolValueBalanceBefore, "Carol should have same value balance");

        // voteVault should have zero remaining inflationary rewards from epoch 1
        assertEq(
            value.balanceOf(address(voteVault)),
            valueInitialBalanceForVault,
            "voteVault should not have any remaining tokens"
        );

        // alice and bobs combined balance minus what they had before should be the entire reward
        uint256 aliceAndBobReceivedValueTokenRewards =
            value.balanceOf(alice) + value.balanceOf(bob) - aliceValueBalanceBefore - bobValueBalanceBefore;
        assertEq(
            aliceAndBobReceivedValueTokenRewards, valueBalanceForVaultForEpochOne, "rewards were not distrubuted evenly"
        );
    }

    function test_flowForUserToClaimValueTokenRewardsForManyEpochs() public {
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        uint256 valueBalanceForVaultBefore = value.balanceOf(address(voteVault));

        uint256[] memory epochs = new uint256[](2);

        // voting period started epcch 1
        vm.roll(block.number + governor.votingDelay() + 1);

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        // voting period started epoch 2
        vm.roll(block.number + governor.votingDelay() + 1);

        epochs[0] = governor.currentEpoch() - 1;

        // alice votes on proposal 2
        vm.startPrank(alice);
        governor.castVote(proposalId2, yesVote);
        vm.stopPrank();

        uint256 proposal3;
        (proposal3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // voting period started epoch 3
        vm.roll(block.number + governor.votingDelay() + 1);

        epochs[1] = governor.currentEpoch() - 1;
        // ALICE DOES NOT vote on proposal 3

        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 valueBalanceForVaultAfter = value.balanceOf(address(voteVault));

        assertGt(
            valueBalanceForVaultAfter,
            valueBalanceForVaultBefore,
            "voteVault should have received the inflationary rewards from epochs 1, 2 and 3"
        );

        // alice claims her value token inflation rewards for epochs 1 and 2.

        uint256 aliceBalanceBeforeClaiming = value.balanceOf(alice);

        uint256 voteVaultBalanceBeforeAliceClaiming = value.balanceOf(address(voteVault));

        vm.startPrank(alice);
        voteVault.withdraw(epochs, address(value));
        vm.stopPrank();

        uint256 aliceBalanceAfterClaiming = value.balanceOf(alice);

        uint256 voteVaultBalanceAfterAliceClaiming = value.balanceOf(address(voteVault));

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 1, address(value)),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 2, address(value)),
            "Alice should have claimed vote token rewards"
        );

        assertGt(aliceBalanceAfterClaiming, aliceBalanceBeforeClaiming, "Alice should have more value balance");

        assertLt(
            voteVaultBalanceAfterAliceClaiming,
            voteVaultBalanceBeforeAliceClaiming,
            "voteVault should have less value balance"
        );

        // alice claims for an epoch she is not entitled to rewards
        uint256[] memory unentitledRewards = new uint256[](1);
        unentitledRewards[0] = governor.currentEpoch() - 1;

        vm.startPrank(alice);
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.withdraw(unentitledRewards, address(value));
        vm.stopPrank();
    }
}
