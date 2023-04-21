// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract Vault_WithdrawValueTokenRewards is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    address carol = createUser("carol");

    uint256 spogVoteAmountToMint = 1000e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function proposeAddingNewListToSpog(string memory proposalDescription)
        private
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = voteGovernor.hashProposal(targets, values, calldatas, hashedDescription);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    // calculate value token inflation rewards for voter
    function calculateValueTokenInflationRewardsForVoter(
        address voter,
        uint256 proposalId,
        uint256 amountToBeSharedOnProRataBasis
    ) private view returns (uint256) {
        uint256 relevantVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch() - 1;

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
        // set up proposals
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // mint ether and spogVote to alice, bob and carol
        vm.deal({account: alice, newBalance: 1000 ether});
        spogVote.mint(alice, spogVoteAmountToMint);
        vm.startPrank(alice);
        spogVote.delegate(alice); // self delegate
        vm.stopPrank();

        vm.deal({account: bob, newBalance: 1000 ether});
        spogVote.mint(bob, spogVoteAmountToMint);
        vm.startPrank(bob);
        spogVote.delegate(bob); // self delegate
        vm.stopPrank();

        vm.deal({account: carol, newBalance: 1000 ether});
        spogVote.mint(carol, spogVoteAmountToMint);
        vm.startPrank(carol);
        spogVote.delegate(carol); // self delegate
        vm.stopPrank();

        // balance of spogValue for vault should be 0
        uint256 spogValueBalanceForVaultForEpochZero = spogValue.balanceOf(address(vault));
        assertEq(spogValueBalanceForVaultForEpochZero, 0, "vault should have 0 spogVote balance");

        // voting period started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);
        voteGovernor.updateStartOfNextVotingPeriod();
        valueGovernor.updateStartOfNextVotingPeriod();

        vm.prank(address(valueGovernor));
        uint256 epochInflation = spog.tokenInflationCalculation();

        uint256 spogValueBalanceForVaultForEpochOne = spogValue.balanceOf(address(vault));
        assertGt(
            spogValueBalanceForVaultForEpochOne,
            spogValueBalanceForVaultForEpochZero,
            "vault should have more spogVote balance"
        );

        // alice votes on proposal 1, 2 and 3
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        voteGovernor.castVote(proposalId2, yesVote);
        voteGovernor.castVote(proposalId3, noVote);
        vm.stopPrank();

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
        voteGovernor.updateStartOfNextVotingPeriod();
        valueGovernor.updateStartOfNextVotingPeriod();

        uint256 aliceValueBalanceBefore = spogValue.balanceOf(alice);
        uint256 bobValueBalanceBefore = spogValue.balanceOf(bob);

        uint256 relevantEpoch = valueGovernor.currentVotingPeriodEpoch() - 1;

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
        vault.withdrawValueTokenRewards();
        vm.stopPrank();

        vm.startPrank(bob);
        vault.withdrawValueTokenRewards();
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

        // carol fails to withdraw vote rewards because she has not voted in all proposals
        vm.expectRevert("Vault: unable to withdraw due to not voting on all proposals");
        vault.withdrawValueTokenRewards();
        vm.stopPrank();

        // carol remains with the same balance
        assertEq(spogValue.balanceOf(carol), carolValueBalanceBefore, "Carol should have same spogValue balance");

        // vault should have received the remaining inflationary rewards from epoch 1
        assertGt(
            spogValue.balanceOf(address(vault)),
            spogValueBalanceForVaultForEpochZero,
            "vault should have received the remaining inflationary rewards"
        );
    }
}
