// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";

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
        uint256 accountVotingTokenBalance = voteGovernor.getVotes(voter, voteGovernor.proposalSnapshot(proposalId));

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

        uint256 relevantEpochProposals = voteGovernor.currentEpoch() + 1;

        // epochProposalsCount for epoch 0 should be 3
        assertEq(voteGovernor.epochProposalsCount(relevantEpochProposals), 3, "current epoch should have 3 proposals");

        // cannot vote in epoch 0
        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVote(proposalId, yesVote);

        // voting period started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // alice votes on proposal 1
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes on proposal 1
        vm.startPrank(bob);
        voteGovernor.castVote(proposalId, noVote);
        vm.stopPrank();

        // check that both have voted once in epoch 1
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(alice, relevantEpochProposals),
            1,
            "Alice should have voted once in epoch 1"
        );
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(bob, relevantEpochProposals),
            1,
            "Bob should have voted once in epoch 1"
        );

        // alice and bobs vote token balance should be the same as before voting
        assertEq(spogVote.balanceOf(alice), amountToMint, "Alice should have same spogVote balance");
        assertEq(spogVote.balanceOf(bob), amountToMint, "Bob should have same spogVote balance");

        // alice votes on proposal 2 and 3
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId2, yesVote);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // bob votes on proposal 2 and 3
        vm.startPrank(bob);
        voteGovernor.castVote(proposalId2, noVote);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // check that both alice and bob have voted 3 times in relevant epoch
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(alice, relevantEpochProposals),
            3,
            "Alice should have voted 3 times in epoch 1"
        );
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(bob, relevantEpochProposals),
            3,
            "Bob should have voted 3 times in epoch 1"
        );

        // and carol has not voted at all
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(carol, relevantEpochProposals),
            0,
            "Carol should have voted 0 times in epoch 1"
        );

        assertEq(voteGovernor.epochProposalsCount(relevantEpochProposals), 3, "current epoch should have 3 proposals");

        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpochProposals, address(spogVote)),
            "Alice should not have claimed vote token rewards"
        );
        assertFalse(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpochProposals, address(spogVote)),
            "Bob should not have claimed vote token rewards"
        );

        // alice and bob claim their vote token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        voteVault.claimVoteTokenRewards(relevantEpochProposals);
        vm.stopPrank();

        vm.startPrank(bob);
        voteVault.claimVoteTokenRewards(relevantEpochProposals);
        vm.stopPrank();

        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(alice, relevantEpochProposals, address(spogVote)),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            voteVault.hasClaimedTokenRewardsForEpoch(bob, relevantEpochProposals, address(spogVote)),
            "Bob should have claimed vote token rewards"
        );

        // alice and bobs should have received vote token inflationary rewards from epoch 1 for having voted in all proposals proposed from epoch 0
        assertEq(
            spogVote.balanceOf(alice),
            calculateVoteTokenInflationRewardsForVoter(alice, proposalId, epochInflation)
                + voteGovernor.getVotes(alice, voteGovernor.proposalSnapshot(proposalId)),
            "Alice should have more spogVote balance"
        );
        assertEq(
            spogVote.balanceOf(bob),
            calculateVoteTokenInflationRewardsForVoter(bob, proposalId, epochInflation)
                + voteGovernor.getVotes(bob, voteGovernor.proposalSnapshot(proposalId)),
            "Bob should have more spogVote balance"
        );

        // alice and bob have received the same amount of inflation rewards so their balance are the same
        assertEq(spogVote.balanceOf(alice), spogVote.balanceOf(bob), "Alice and Bob should have same spogVote balance");

        // carol votes on proposal 3 only
        vm.startPrank(carol);
        voteGovernor.castVote(proposalId3, noVote);

        // carol fails to withdraw vote rewards because she has not voted in all proposals
        vm.expectRevert("Vault: unable to withdraw due to not voting on all proposals");
        voteVault.claimVoteTokenRewards(relevantEpochProposals);

        vm.stopPrank();

        // carol voted in 1 proposal
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(carol, relevantEpochProposals),
            1,
            "Carol should have voted 1 times in epoch 1"
        );

        // voting epoch 1 finished, epoch 2 started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // carol remains with the same balance
        assertEq(spogVote.balanceOf(carol), amountToMint, "Carol should have same spogVote balance");

        // voteVault should have received the remaining inflationary rewards from epoch 1
        assertGt(
            spogVote.balanceOf(address(voteVault)),
            spogVoteInitialBalanceForVault,
            "voteVault should have received the remaining inflationary rewards from epoch 1"
        );
    }
}
