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
        // start balance of spogValue for vault should be 0
        uint256 spogValueInitialBalanceForVault = spogValue.balanceOf(address(vault));
        assertEq(spogValueInitialBalanceForVault, 0, "vault should have 0 spogValue balance");
        assertEq(
            spog.valueTokenInflationPerEpoch(),
            spog.valueFixedInflationAmount(),
            "inflation should be equal to fixed value reward"
        );

        // set up proposals and inflate supply
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        uint256 spogValueBalanceForVaultAfterProposals = spogValue.balanceOf(address(vault));
        assertEq(
            spogValueBalanceForVaultAfterProposals,
            spog.valueTokenInflationPerEpoch(),
            "vault should have value inflation rewards balance"
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

        uint256 spogValueBalanceForVaultForEpochOne = spogValue.balanceOf(address(vault));
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

        assertFalse(
            vault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(spogValue)),
            "Alice should not have claimed value token rewards"
        );
        assertFalse(
            vault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(spogValue)),
            "Bob should not have claimed value token rewards"
        );

        // alice and bob withdraw their value token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        vault.claimValueTokenRewards();
        vm.stopPrank();

        vm.startPrank(bob);
        vault.claimValueTokenRewards();
        vm.stopPrank();

        assertTrue(
            vault.hasClaimedTokenRewardsForEpoch(alice, relevantEpoch, address(spogValue)),
            "Alice should have claimed value token rewards"
        );
        assertTrue(
            vault.hasClaimedTokenRewardsForEpoch(bob, relevantEpoch, address(spogValue)),
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
        vm.expectRevert("Vault: unable to withdraw due to not voting on all proposals");
        vault.claimValueTokenRewards();
        vm.stopPrank();

        // carol remains with the same balance
        assertEq(spogValue.balanceOf(carol), carolValueBalanceBefore, "Carol should have same spogValue balance");

        // vault should have zero remaining inflationary rewards from epoch 1
        assertEq(
            spogValue.balanceOf(address(vault)),
            spogValueInitialBalanceForVault,
            "vault should not have any remaining tokens"
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
}
