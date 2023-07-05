// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import "forge-std/console.sol";

contract InflationRewardsTest is SPOG_Base {
    function test_UserVoteInflationAfterVotingOnAllProposals() public {
        // set up proposals
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // cannot vote in epoch 0
        vm.expectRevert("DualGovernor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 aliceVotes = governor.vote().getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        uint256 aliceVotesAfterFirstVote = governor.vote().getVotes(alice);
        assertEq(aliceVotesAfterFirstVote, aliceVotes, "No rewards yet, alice has not voted on all proposals");

        // alice and bobs vote token balance should be the same as before voting
        assertEq(vote.balanceOf(alice), amountToMint, "Alice should have same vote balance");
        assertEq(vote.balanceOf(bob), amountToMint, "Bob should have same vote balance");

        // alice votes on proposal 2 and 3
        vm.startPrank(alice);
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, noVote);

        assertEq(
            vote.balanceOf(alice), amountToMint, "Alice should have same vote balance, she didn't claim rewards yet"
        );

        uint256 aliceVotesAfterAllProposals = governor.vote().getVotes(alice);
        uint256 votesAfterVoting = aliceVotes + spog.inflator() * aliceVotes / 100;
        assertEq(
            aliceVotesAfterAllProposals, votesAfterVoting, "Alice should have more votes after voting on all proposals"
        );

        uint256 rewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        assertEq(rewards, aliceStartBalance * spog.inflator() / 100, "Alice should have received inflation rewards");

        assertEq(vote.balanceOf(alice), aliceStartBalance + rewards, "Alice should have more vote tokens");
    }

    function test_UsersVoteInflationForMultipleEpochs() public {
        vote.mint(bob, amountToMint * 1);
        vote.mint(carol, amountToMint * 2);

        uint256 aliceStartVotes = vote.getVotes(alice);
        uint256 bobStartVotes = vote.getVotes(bob);
        uint256 carolStartVotes = vote.getVotes(carol);

        assertEq(vote.balanceOf(alice), 100e18);
        assertEq(vote.balanceOf(bob), 200e18);
        assertEq(vote.balanceOf(carol), 300e18);

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);
        vm.stopPrank();
        // bob votes on proposal 1
        vm.startPrank(bob);
        governor.castVote(proposal1Id, yesVote);
        vm.stopPrank();
        uint256 aliceVotesAfterFirstVote = vote.getVotes(alice);
        uint256 bobVotesAfterFirstVote = vote.getVotes(bob);
        assertEq(bobVotesAfterFirstVote, bobStartVotes * (100 + spog.inflator()) / 100);
        assertEq(aliceVotesAfterFirstVote, aliceStartVotes * (100 + spog.inflator()) / 100);
        assertEq(vote.getVotes(carol), carolStartVotes);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // set up proposals
        (uint256 proposal2Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 2");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal2Id, yesVote);
        vm.stopPrank();
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(vote.getVotes(alice), aliceVotesAfterFirstVote * (100 + spog.inflator()) / 100);
        assertEq(vote.getVotes(bob), bobVotesAfterFirstVote);
        // carol has no rewards, didn't vote on proposals
        assertEq(vote.getVotes(carol), carolStartVotes);

        vm.startPrank(alice);
        uint256 aliceRewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobRewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        vm.stopPrank();

        vm.startPrank(carol);
        uint256 carolRewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        vm.stopPrank();

        assertEq(aliceRewards, 44e18, "Incorrect alice rewards");
        assertEq(bobRewards, 40e18, "Incorrect bob rewards");
        assertEq(carolRewards, 0, "Incorrect carol rewards");

        assertEq(vote.balanceOf(alice), 144e18, "Incorrect alice balance");
        assertEq(vote.balanceOf(bob), 240e18, "Incorrect bob balance");
        assertEq(vote.balanceOf(carol), 300e18, "Incorrect carol balance");
    }

    function test_UsersVoteInflationUpgradeOnDelegation() public {
        uint256 aliceStartVotes = vote.getVotes(alice);

        assertEq(vote.balanceOf(alice), 100e18);

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        uint256 aliceVotesAfterFirstVote = vote.getVotes(alice);
        assertEq(aliceVotesAfterFirstVote, aliceStartVotes * (100 + spog.inflator()) / 100);

        uint256 bobVotes = vote.getVotes(bob);
        assertEq(bobVotes, 100e18);
        // alice delegates her voting power with rewards to bob
        assertEq(InflationaryVotes(address(vote)).getUnclaimedVoteRewards(alice), 0);
        vote.delegate(bob);
        assertEq(InflationaryVotes(address(vote)).getUnclaimedVoteRewards(alice), 20e18);
        assertEq(vote.getVotes(bob), bobVotes + aliceVotesAfterFirstVote);

        // alice claims her voting rewards
        uint256 aliceRewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        assertEq(vote.getVotes(bob), 220e18);
        assertEq(vote.balanceOf(alice), 120e18, "Incorrect alice balance");
        // alice balances increased, but delegate voting power did not, it already accounted for
        assertEq(vote.getVotes(bob), 220e18);
        vm.stopPrank();

        // bob attempts to claim rewards
        vm.startPrank(bob);
        uint256 bobRewards = InflationaryVotes(address(governor.vote())).claimVoteRewards();
        assertEq(bobRewards, 0, "Incorrect bob rewards");
        assertEq(vote.balanceOf(bob), 100e18, "Incorrect bob balance");

        assertEq(vote.totalSupply(), InflationaryVotes(address(vote)).totalVotes());
    }

    function test_UsersVoteInflationWorksWithTransfer() public {
        assertEq(vote.balanceOf(alice), 100e18);

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);
        assertEq(InflationaryVotes(address(vote)).getUnclaimedVoteRewards(alice), 0);
        vm.stopPrank();

        vm.startPrank(bob);
        // bob transfers tokens to alice
        vote.transfer(alice, 10e18);
        assertEq(InflationaryVotes(address(vote)).getUnclaimedVoteRewards(alice), 0);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        vm.stopPrank();

        assertEq(vote.getVotes(alice), 130e18);
        assertEq(vote.getVotes(bob), 90e18);
        assertEq(vote.balanceOf(alice), 130e18);
        assertEq(vote.balanceOf(bob), 90e18);

        // bob votes too
        vm.startPrank(bob);
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(bob), 110e18);
        uint256 bobRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(bobRewards, 20e18, "Incorrect alice rewards");
        vm.stopPrank();

        assertEq(vote.getVotes(alice), 130e18);
        assertEq(vote.getVotes(bob), 110e18);
        assertEq(vote.balanceOf(alice), 130e18);
        assertEq(vote.balanceOf(bob), 110e18);
    }

    function test_UserGetRewardOnlyOncePerEpochIfRedelegating() public {
        assertEq(vote.balanceOf(alice), 100e18);

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);

        // redelegate voting power to bob
        vote.delegate(bob);
        assertEq(vote.getVotes(bob), 220e18, "Bob voting power includes alice initial voting power + reward");
        vm.stopPrank();

        vm.startPrank(bob);
        governor.castVote(proposal1Id, yesVote);
        assertEq(
            vote.getVotes(bob),
            240e18,
            "Bob voting power includes alice initial voting power + reward + reward for voting"
        );
        assertEq(
            InflationaryVotes(address(vote)).getUnclaimedVoteRewards(alice), 20e18, "Alice vote rewards are incorrect"
        );
        uint256 bobRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(bobRewards, 20e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");

        assertEq(vote.balanceOf(alice), 120e18);
        assertEq(vote.balanceOf(bob), 120e18);
        assertEq(vote.getVotes(bob), vote.balanceOf(bob) + vote.balanceOf(alice));
    }

    function test_UserGetDelayedRewardWhileRedelegating() public {
        assertEq(vote.balanceOf(alice), 100e18);

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");
        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.startPrank(alice);
        // redelegate voting power to bob
        vote.delegate(bob);
        assertEq(vote.getVotes(bob), 200e18, "Bob voting power includes alice initial voting power");
        vm.stopPrank();

        vm.startPrank(bob);
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(bob), 220e18, "Bob voting power includes alice initial voting power + reward for voting");

        uint256 bobRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(bobRewards, 20e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards1 = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(aliceRewards1, 0, "Incorrect alice rewards");

        governor.castVote(proposal1Id, yesVote);
        uint256 aliceRewards2 = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(aliceRewards2, 20e18, "Incorrect alice rewards");
        assertEq(vote.balanceOf(alice), 120e18, "Alice balance was not updated");
        vm.stopPrank();
    }

    function test_VotingPowerForDelegates() public {
        // all users self-delegate at the beginning
        assertEq(vote.getVotes(alice), 100e18);
        assertEq(vote.getVotes(bob), 100e18);
        assertEq(vote.getVotes(carol), 100e18);
        uint256 extraTotalVotes = InflationaryVotes(address(vote)).totalVotes() - 300e18;

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);
        uint256 aliceRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        vm.stopPrank();

        vm.startPrank(bob);
        vote.transfer(carol, 50e18);
        // bob votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // takes into account voting power at the beginning of epoch
        assertEq(vote.getVotes(bob), 70e18);
        uint256 bobRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(bobRewards, 20e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(carol);
        // carol votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // takes into account voting power at the beginning of epoch
        assertEq(vote.getVotes(carol), 170e18);
        uint256 carolRewards = InflationaryVotes(address(vote)).claimVoteRewards();
        assertEq(carolRewards, 20e18, "Incorrect carol rewards");
        vm.stopPrank();

        assertEq(
            vote.balanceOf(alice) + vote.balanceOf(bob) + vote.balanceOf(carol),
            InflationaryVotes(address(vote)).totalVotes() - extraTotalVotes
        );
    }
}
