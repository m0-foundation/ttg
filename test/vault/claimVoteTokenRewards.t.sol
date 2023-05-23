// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";
import {IVoteVault} from "src/interfaces/vaults/IVoteVault.sol";

contract Vault_WithdrawVoteTokenRewards is Vault_IntegratedWithSPOG {
    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // calculate vote token inflation rewards for voter
    function calculateVoteTokenInflationRewardsForVoter(
        address voter,
        uint256 proposalId,
        uint256 amountToBeSharedOnProRataBasis
    ) private view returns (uint256) {
        uint256 accountVotingTokenBalance = governor.getVotes(voter, governor.proposalSnapshot(proposalId));

        uint256 totalVotingTokenSupplyApplicable = spogVote.totalSupply() - amountToBeSharedOnProRataBasis;

        uint256 percentageOfTotalSupply = accountVotingTokenBalance * 100 / totalVotingTokenSupplyApplicable;

        uint256 inflationRewards = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        return inflationRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UsersGetsVoteTokenInflationAfterVotingOnAllProposals() public {
        // balance of spogVote for voteVault should be 0 before proposals
        uint256 spogVoteInitialBalanceForVault = spogVote.balanceOf(address(voteVault));
        assertEq(spogVoteInitialBalanceForVault, 0, "voteVault should have 0 spogVote balance");

        uint256 epochInflation = spogVote.totalSupply() * deployScript.inflator() / 100;
        assertEq(
            spog.voteTokenInflationPerEpoch(), epochInflation, "inflation should be equal to totalSupply * inflator"
        );

        // set up proposals
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        uint256 spogVoteBalanceForVaultForEpochOne = spogVote.balanceOf(address(voteVault));
        assertEq(
            spogVoteInitialBalanceForVault + epochInflation,
            spogVoteBalanceForVaultForEpochOne,
            "voteVault should have more spogVote balance"
        );

        uint256 nextEpoch = governor.currentEpoch() + 1;
        uint256[] memory relevantEpochs = new uint256[](1);
        relevantEpochs[0] = nextEpoch;

        // epochProposalsCount for epoch 0 should be 3
        assertEq(governor.epochProposalsCount(nextEpoch), 3, "current epoch should have 3 proposals");

        // cannot vote in epoch 0
        vm.expectRevert("Governor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes on proposal 1
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        // check that both have voted once in epoch 1
        assertEq(
            governor.accountEpochNumProposalsVotedOn(alice, nextEpoch), 1, "Alice should have voted once in epoch 1"
        );
        assertEq(governor.accountEpochNumProposalsVotedOn(bob, nextEpoch), 1, "Bob should have voted once in epoch 1");

        // alice and bobs vote token balance should be the same as before voting
        assertEq(spogVote.balanceOf(alice), amountToMint, "Alice should have same spogVote balance");
        assertEq(spogVote.balanceOf(bob), amountToMint, "Bob should have same spogVote balance");

        // alice votes on proposal 2 and 3
        vm.startPrank(alice);
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // bob votes on proposal 2 and 3
        vm.startPrank(bob);
        governor.castVote(proposalId2, noVote);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // check that both alice and bob have voted 3 times in relevant epoch
        assertEq(
            governor.accountEpochNumProposalsVotedOn(alice, nextEpoch), 3, "Alice should have voted 3 times in epoch 1"
        );
        assertEq(
            governor.accountEpochNumProposalsVotedOn(bob, nextEpoch), 3, "Bob should have voted 3 times in epoch 1"
        );

        // and carol has not voted at all
        assertEq(
            governor.accountEpochNumProposalsVotedOn(carol, nextEpoch), 0, "Carol should have voted 0 times in epoch 1"
        );

        assertEq(governor.epochProposalsCount(nextEpoch), 3, "current epoch should have 3 proposals");

        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, nextEpoch, address(spogVote)),
            "Alice should not have claimed vote token rewards"
        );
        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, nextEpoch, address(spogVote)),
            "Bob should not have claimed vote token rewards"
        );

        // alice and bob claim their vote token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        voteVault.claimRewards(relevantEpochs, address(spogVote));
        vm.stopPrank();

        vm.startPrank(bob);
        voteVault.claimRewards(relevantEpochs, address(spogVote));
        vm.stopPrank();

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpochs[0], address(spogVote)),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpochs[0], address(spogVote)),
            "Bob should have claimed vote token rewards"
        );

        // alice and bobs should have received vote token inflationary rewards from epoch 1 for having voted in all proposals proposed from epoch 0
        assertEq(
            spogVote.balanceOf(alice),
            calculateVoteTokenInflationRewardsForVoter(alice, proposalId, epochInflation)
                + governor.getVotes(alice, governor.proposalSnapshot(proposalId)),
            "Alice should have more spogVote balance"
        );
        assertEq(
            spogVote.balanceOf(bob),
            calculateVoteTokenInflationRewardsForVoter(bob, proposalId, epochInflation)
                + governor.getVotes(bob, governor.proposalSnapshot(proposalId)),
            "Bob should have more spogVote balance"
        );

        // alice and bob have received the same amount of inflation rewards so their balance are the same
        assertEq(spogVote.balanceOf(alice), spogVote.balanceOf(bob), "Alice and Bob should have same spogVote balance");

        // carol votes on proposal 3 only
        vm.startPrank(carol);
        governor.castVote(proposalId3, noVote);

        // carol fails to withdraw vote rewards because she has not voted in all proposals
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.claimRewards(relevantEpochs, address(spogVote));

        vm.stopPrank();

        // carol voted in 1 proposal
        assertEq(
            governor.accountEpochNumProposalsVotedOn(carol, relevantEpochs[0]),
            1,
            "Carol should have voted 1 times in epoch 1"
        );

        // voting epoch 1 finished, epoch 2 started
        vm.roll(block.number + governor.votingDelay() + 1);

        // carol remains with the same balance
        assertEq(spogVote.balanceOf(carol), amountToMint, "Carol should have same spogVote balance");

        // voteVault should have received the remaining inflationary rewards from epoch 1
        assertGt(
            spogVote.balanceOf(address(voteVault)),
            spogVoteInitialBalanceForVault,
            "voteVault should have received the remaining inflationary rewards from epoch 1"
        );
    }

    function test_flowForUserToClaimVoteTokenRewardsForManyEpochs() public {
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        uint256 spogVoteBalanceForVaultBefore = spogVote.balanceOf(address(voteVault));

        uint256[] memory epochs = new uint256[](2);
        epochs[0] = governor.currentEpoch() + 1;

        // voting period started epcch 1
        vm.roll(block.number + governor.votingDelay() + 1);

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        epochs[1] = governor.currentEpoch() + 1;

        // voting period started epoch 2
        vm.roll(block.number + governor.votingDelay() + 1);

        // alice votes on proposal 2
        vm.startPrank(alice);
        governor.castVote(proposalId2, yesVote);
        vm.stopPrank();

        uint256 proposal3;
        (proposal3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // voting period started epoch 3
        vm.roll(block.number + governor.votingDelay() + 1);

        // ALICE DOES NOT vote on proposal 3

        uint256 spogVoteBalanceForVaultAfter = spogVote.balanceOf(address(voteVault));

        assertGt(
            spogVoteBalanceForVaultAfter,
            spogVoteBalanceForVaultBefore,
            "voteVault should have received the inflationary rewards from epochs 1, 2 and 3"
        );

        // alice claims her vote token inflation rewards for epochs 1 and 2.

        uint256 aliceBalanceBeforeClaiming = spogVote.balanceOf(alice);

        uint256 voteVaultBalanceBeforeAliceClaiming = spogVote.balanceOf(address(voteVault));

        vm.startPrank(alice);
        voteVault.claimRewards(epochs, address(spogVote));
        vm.stopPrank();

        uint256 aliceBalanceAfterClaiming = spogVote.balanceOf(alice);

        uint256 voteVaultBalanceAfterAliceClaiming = spogVote.balanceOf(address(voteVault));

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 1, address(spogVote)),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, 2, address(spogVote)),
            "Alice should have claimed vote token rewards"
        );

        assertGt(aliceBalanceAfterClaiming, aliceBalanceBeforeClaiming, "Alice should have more spogVote balance");

        assertLt(
            voteVaultBalanceAfterAliceClaiming,
            voteVaultBalanceBeforeAliceClaiming,
            "voteVault should have less spogVote balance"
        );

        // alice claims for an epoch she is not entitled to rewards
        uint256[] memory unentitledRewards = new uint256[](1);
        unentitledRewards[0] = governor.currentEpoch();

        vm.startPrank(alice);
        vm.expectRevert(IVoteVault.NotVotedOnAllProposals.selector);
        voteVault.claimRewards(unentitledRewards, address(spogVote));
        vm.stopPrank();
    }
}
