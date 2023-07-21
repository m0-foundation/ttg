// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract RewardsTest is SPOGBaseTest {
    function test_DelegateValueRewardsAfterVotingOnAllProposals() public {
        // set up proposals
        (uint256 proposalId, , , , ) = proposeAddingAnAddressToList(makeAddr("Alpha"));
        (uint256 proposalId2, , , , ) = proposeAddingAnAddressToList(makeAddr("Beta"));
        (uint256 proposalId3, , , , ) = proposeAddingAnAddressToList(makeAddr("Omega"));

        // voting period started
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        uint256 aliceStartBalance = value.balanceOf(alice);
        uint256 bobStartBalance = value.balanceOf(bob);

        assertEq(aliceStartBalance, bobStartBalance, "Alice and Bob should have same value balance before voting");
        assertEq(vote.getVotes(alice), vote.getVotes(bob), "Alice and Bob should have same voting power before voting");

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);

        uint256 aliceBalanceAfterVote = value.balanceOf(alice);
        assertEq(
            aliceStartBalance,
            aliceBalanceAfterVote,
            "No value rewards yet, Alice has not voted on all proposals"
        );

        // alice votes on proposal 2 and 3
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, noVote);
        vm.stopPrank();

        // alice votes on proposal 1, 2 and 3
        vm.startPrank(bob);
        governor.castVote(proposalId, yesVote);
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, yesVote);
        vm.stopPrank();

        uint256 aliceReward = spog.fixedReward() / 4;
        uint256 bobReward = spog.fixedReward() / 4;

        assertEq(
            value.balanceOf(alice),
            value.balanceOf(bob),
            "Alice and Bob should have same value balance after voting"
        );
        assertEq(aliceStartBalance + aliceReward, value.balanceOf(alice), "Invalid Alice VALUE reward");
        assertEq(bobStartBalance + bobReward, value.balanceOf(bob), "Invalid Bob Value reward");
    }
}
