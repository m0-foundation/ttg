// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

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
        uint256 relevantVotingPeriodEpoch = voteGovernor.currentEpoch() - 1;

        uint256 accountVotingTokenBalance = voteGovernor.getVotes(voter, voteGovernor.proposalSnapshot(proposalId));

        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochSumOfVoteWeight(relevantVotingPeriodEpoch);

        uint256 percentageOfTotalSupply = accountVotingTokenBalance * 100 / totalVotingTokenSupplyApplicable;

        uint256 inflationRewards = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        return inflationRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UsersCanClaimValueTokenInflationAfterVotingOnInAllProposals() public {
        // start balance of spogValue for voteVault should be 0
        uint256 spogValueInitialBalanceForVault = spogValue.balanceOf(address(voteVault));
        assertEq(spogValueInitialBalanceForVault, 0, "voteVault should have 0 spogValue balance");
        assertEq(
            spog.valueTokenInflationPerEpoch(),
            spog.valueFixedInflationAmount(),
            "inflation should be equal to fixed value reward"
        );

        // set up proposals and inflate supply
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        uint256 spogValueBalanceForVaultAfterProposals = spogValue.balanceOf(address(voteVault));
        assertEq(
            spogValueBalanceForVaultAfterProposals,
            spog.valueTokenInflationPerEpoch(),
            "voteVault should have value inflation rewards balance"
        );

        // voting period started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 epochInflation = spog.valueTokenInflationPerEpoch();

        // alice votes on proposal 1, 2 and 3
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        voteGovernor.castVote(proposalId2, yesVote);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

        uint256 spogValueBalanceForVaultForEpochOne = spogValue.balanceOf(address(voteVault));
        assertEq(
            spogValueBalanceForVaultForEpochOne,
            spogValueBalanceForVaultAfterProposals,
            "voting does not affect inflation"
        );

        // bob votes on proposal 1, 2 and 3
        vm.startPrank(bob);
        voteGovernor.castVote(proposalId, noVote);
        voteGovernor.castVote(proposalId2, noVote);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // carol doen't vote in all proposals
        vm.startPrank(carol);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // start epoch 2
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 aliceValueBalanceBefore = spogValue.balanceOf(alice);
        uint256 bobValueBalanceBefore = spogValue.balanceOf(bob);

        uint256 relevantEpoch = valueGovernor.currentEpoch() - 1;
        uint256[] memory epochsToClaimRewards = new uint256[](1);
        epochsToClaimRewards[0] = relevantEpoch;

        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(spogValue)),
            "Alice should not have claimed value token rewards"
        );
        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(spogValue)),
            "Bob should not have claimed value token rewards"
        );

        // alice and bob withdraw their value token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        voteVault.claimRewards(relevantEpoch, address(spogValue));
        vm.stopPrank();

        vm.startPrank(bob);
        voteVault.claimRewards(relevantEpoch, address(spogValue));
        vm.stopPrank();

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(spogValue)),
            "Alice should have claimed value token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(spogValue)),
            "Bob should have claimed value token rewards"
        );

        // alice and bobs should have received value token inflationary rewards from epoch 1 in epoch 2
        assertEq(
            spogValue.balanceOf(alice),
            calculateValueTokenInflationRewardsForVoter(alice, proposalId, epochInflation) + aliceValueBalanceBefore,
            "Alice has unexpected balance"
        );
        assertEq(
            spogValue.balanceOf(bob),
            calculateValueTokenInflationRewardsForVoter(bob, proposalId, epochInflation) + bobValueBalanceBefore,
            "Bob has unexpected balance"
        );

        // alice and bob have received the same amount of inflation rewards so their balance are the same
        assertEq(
            spogValue.balanceOf(alice), spogValue.balanceOf(bob), "Alice and Bob should have same spogVote balance"
        );

        vm.startPrank(carol);

        uint256 carolValueBalanceBefore = spogValue.balanceOf(carol);

        // carol fails to withdraw value token rewards because she has not voted in all proposals
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.claimRewards(relevantEpoch, address(spogValue));
        vm.stopPrank();

        // carol remains with the same balance
        assertEq(spogValue.balanceOf(carol), carolValueBalanceBefore, "Carol should have same spogValue balance");

        // voteVault should have zero remaining inflationary rewards from epoch 1
        assertEq(
            spogValue.balanceOf(address(voteVault)),
            spogValueInitialBalanceForVault,
            "voteVault should not have any remaining tokens"
        );

        // alice and bobs combined balance minus what they had before should be the entire reward
        uint256 aliceAndBobReceivedValueTokenRewards =
            spogValue.balanceOf(alice) + spogValue.balanceOf(bob) - aliceValueBalanceBefore - bobValueBalanceBefore;
        assertEq(
            aliceAndBobReceivedValueTokenRewards,
            spogValueBalanceForVaultForEpochOne,
            "rewards were not distrubuted evenly"
        );
    }

    function test_flowForUserToClaimValueTokenRewardsForManyEpochs() public {
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        uint256 spogValueBalanceForVaultBefore = spogValue.balanceOf(address(voteVault));

        uint256[] memory epochs = new uint256[](2);

        // voting period started epcch 1
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // alice votes on proposal 1
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        // voting period started epoch 2
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        epochs[0] = voteGovernor.currentEpoch() - 1;

        // alice votes on proposal 2
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId2, yesVote);
        vm.stopPrank();

        uint256 proposal3;
        (proposal3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // voting period started epoch 3
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        epochs[1] = voteGovernor.currentEpoch() - 1;
        // ALICE DOES NOT vote on proposal 3

        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 spogValueBalanceForVaultAfter = spogValue.balanceOf(address(voteVault));

        assertGt(
            spogValueBalanceForVaultAfter,
            spogValueBalanceForVaultBefore,
            "voteVault should have received the inflationary rewards from epochs 1, 2 and 3"
        );

        // alice claims her value token inflation rewards for epochs 1 and 2.

        uint256 aliceBalanceBeforeClaiming = spogValue.balanceOf(alice);

        uint256 voteVaultBalanceBeforeAliceClaiming = spogValue.balanceOf(address(voteVault));

        vm.startPrank(alice);
        voteVault.claimRewards(epochs, address(spogValue));
        vm.stopPrank();

        uint256 aliceBalanceAfterClaiming = spogValue.balanceOf(alice);

        uint256 voteVaultBalanceAfterAliceClaiming = spogValue.balanceOf(address(voteVault));

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 1, address(spogValue)),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 2, address(spogValue)),
            "Alice should have claimed vote token rewards"
        );

        assertGt(aliceBalanceAfterClaiming, aliceBalanceBeforeClaiming, "Alice should have more spogValue balance");

        assertLt(
            voteVaultBalanceAfterAliceClaiming,
            voteVaultBalanceBeforeAliceClaiming,
            "voteVault should have less spogValue balance"
        );

        // alice claims for an epoch she is not entitled to rewards
        uint256[] memory unentitledRewards = new uint256[](1);
        unentitledRewards[0] = voteGovernor.currentEpoch() - 1;

        vm.startPrank(alice);
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.claimRewards(unentitledRewards, address(spogValue));
        vm.stopPrank();
    }
}
