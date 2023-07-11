// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SPOGBaseTest } from "./shared/SPOGBaseTest.t.sol";

contract InflationRewardsTest is SPOGBaseTest {

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

        uint256 aliceVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);

        uint256 aliceVotesAfterFirstVote = vote.getVotes(alice);
        assertEq(aliceVotesAfterFirstVote, aliceVotes, "No rewards yet, alice has not voted on all proposals");

        // alice and bobs vote token balance should be the same as before voting
        assertEq(vote.balanceOf(alice), amountToMint, "Alice should have same vote balance");
        assertEq(vote.balanceOf(bob), amountToMint, "Bob should have same vote balance");

        // alice votes on proposal 2 and 3
        governor.castVote(proposalId2, yesVote);
        governor.castVote(proposalId3, noVote);

        assertEq(
            vote.balanceOf(alice), amountToMint, "Alice should have same vote balance, she didn't claim rewards yet"
        );

        uint256 aliceVotesAfterAllProposals = vote.getVotes(alice);
        uint256 votesAfterVoting = aliceVotes + spog.inflator() * aliceVotes / 100;
        assertEq(
            aliceVotesAfterAllProposals, votesAfterVoting, "Alice should have more votes after voting on all proposals"
        );

        uint256 rewards = vote.withdrawRewards();
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
        uint256 aliceRewards = vote.withdrawRewards();
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobRewards = vote.withdrawRewards();
        vm.stopPrank();

        vm.startPrank(carol);
        uint256 carolRewards = vote.withdrawRewards();
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
        vote.delegate(bob);

        // alice claims her voting rewards
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        assertEq(vote.getVotes(bob), 220e18);
        assertEq(vote.balanceOf(alice), 120e18, "Incorrect alice balance");
        // alice balances increased, but delegate voting power did not, it already accounted for
        assertEq(vote.getVotes(bob), 220e18);
        vm.stopPrank();

        // bob attempts to claim rewards
        vm.startPrank(bob);
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 0, "Incorrect bob rewards");
        assertEq(vote.balanceOf(bob), 100e18, "Incorrect bob balance");

        assertEq(vote.totalSupply(), vote.totalVotes());
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
        vm.stopPrank();

        vm.startPrank(bob);
        // bob transfers tokens to alice
        vote.transfer(alice, 10e18);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        vm.stopPrank();

        assertEq(vote.getVotes(alice), 130e18);
        assertEq(vote.balanceOf(alice), 130e18);
        assertEq(vote.balanceOf(bob), 90e18);
        assertEq(vote.getVotes(bob), 90e18);

        // bob votes too
        vm.startPrank(bob);
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(bob), 108e18);
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 18e18, "Incorrect bob rewards");
        vm.stopPrank();

        assertEq(vote.getVotes(alice), 130e18);
        assertEq(vote.getVotes(bob), 108e18);
        assertEq(vote.balanceOf(alice), 130e18);
        assertEq(vote.balanceOf(bob), 108e18);
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
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 20e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");

        assertEq(vote.balanceOf(alice), 120e18);
        assertEq(vote.balanceOf(bob), 120e18);
        assertEq(vote.getVotes(bob), vote.balanceOf(bob) + vote.balanceOf(alice));
    }

    function test_UserDoesNotGetDelayedRewardWhileRedelegating() public {
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

        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 20e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards1 = vote.withdrawRewards();
        assertEq(aliceRewards1, 0, "Incorrect alice rewards");

        governor.castVote(proposal1Id, yesVote);
        uint256 aliceRewards2 = vote.withdrawRewards();
        assertEq(aliceRewards2, 0, "Incorrect alice rewards");
        assertEq(vote.balanceOf(alice), 100e18, "Alice balance was not updated");
        vm.stopPrank();
    }

    function test_VotingPowerForDelegates() public {
        // all users self-delegate at the beginning
        assertEq(vote.getVotes(alice), 100e18);
        assertEq(vote.getVotes(bob), 100e18);
        assertEq(vote.getVotes(carol), 100e18);
        uint256 extraTotalVotes = vote.totalVotes() - 300e18;

        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        vm.stopPrank();

        vm.startPrank(bob);
        vote.transfer(carol, 50e18);
        // bob votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // takes into account voting power at the beginning of epoch
        assertEq(vote.getVotes(bob), 60e18);
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 10e18, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(carol);
        // carol votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // takes into account voting power at the beginning of epoch
        assertEq(vote.getVotes(carol), 170e18);
        uint256 carolRewards = vote.withdrawRewards();
        assertEq(carolRewards, 20e18, "Incorrect carol rewards");
        vm.stopPrank();

        assertEq(
            vote.balanceOf(alice) + vote.balanceOf(bob) + vote.balanceOf(carol), vote.totalVotes() - extraTotalVotes
        );
    }

    // TODO: make sure test is still needed
    function test_VotingInflationWithRedelegationInTheSameEpoch() public {
        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        vote.delegate(bob);

        governor.castVote(proposal1Id, yesVote);

        // start new epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 0e18, "Incorrect alice rewards");
    }

    function test_UsersVoteInflationForMultipleEpochsWithRedelegation() public {
        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");

        /// EPOCH 1

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);
        vm.stopPrank();

        vm.startPrank(bob);
        // bob votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(bob), 120e18);
        vm.stopPrank();

        vm.startPrank(carol);
        // carol votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(carol), 120e18, "incorrect carol votes");
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        /// EPOCH 2

        (uint256 proposal2Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 2");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 2
        governor.castVote(proposal2Id, yesVote);
        assertEq(vote.getVotes(alice), 144e18);
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 44e18, "Incorrect alice rewards");
        assertEq(vote.getVotes(bob), 120e18);
        vote.delegate(bob);
        assertEq(vote.getVotes(bob), 264e18);
        vm.stopPrank();

        vm.startPrank(carol);
        // carol redelegates to bob
        assertEq(vote.getVotes(bob), 264e18);
        vote.delegate(bob);
        assertEq(vote.getVotes(bob), 384e18);
        // carol votes on proposal 2
        governor.castVote(proposal2Id, yesVote);
        assertEq(vote.getVotes(carol), 0e18);
        uint256 carolRewards = vote.withdrawRewards();
        // carol doesn't get rewards for this epoch, she voted after re-delegation
        // @note compare carol to alice, alice got rewards for 2 epochs, carol only 1
        assertEq(carolRewards, 20e18, "Incorrect carol rewards");
        assertEq(vote.balanceOf(carol), 120e18, "Incorrect carol balance");
        assertEq(
            vote.getVotes(bob),
            vote.balanceOf(bob) + 20e18 + vote.balanceOf(alice) + vote.balanceOf(carol),
            "Incorrect bob votes"
        );
        vm.stopPrank();

        vm.startPrank(bob);
        // bob votes on proposal 2
        // 120 from bob, 144 from alice, 120 from carol
        assertEq(vote.getVotes(bob), 384e18);
        governor.castVote(proposal2Id, yesVote);
        // 144 from bob, 144 from alice, 120 from carol
        // alice and carol delegated during this epoch, do they votes do not account for voting power inflation
        assertEq(vote.getVotes(bob), 408e18);
        vm.stopPrank();

        vm.startPrank(carol);
        carolRewards = vote.withdrawRewards();
        // carol doesn't get rewards for bob voting
        assertEq(carolRewards, 0e18, "Incorrect carol rewards");
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // epoch - set up proposals
        (uint256 proposal3Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 3");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        /// EPOCH 3

        vm.startPrank(alice);
        // alice votes on proposal 3
        governor.castVote(proposal3Id, yesVote);
        assertEq(vote.getVotes(alice), 0);
        // no rewards for alice, her voting power is 0
        aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 0, "Incorrect alice rewards");
        vm.stopPrank();

        vm.startPrank(bob);
        // bob votes on proposal 3
        assertEq(vote.getVotes(bob), 408e18);
        governor.castVote(proposal3Id, yesVote);
        assertEq(vote.getVotes(bob), 4896e17);
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 728e17, "Incorrect bob rewards");
        vm.stopPrank();
        assertEq(vote.balanceOf(bob), 100e18 * 120 * 120 * 120 / 100 / 100 / 100);
        assertEq(vote.balanceOf(alice), 100e18 * 120 * 120 / 100 / 100);

        vm.startPrank(alice);
        aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 288e17, "Incorrect alice rewards");
        assertEq(vote.balanceOf(alice), 100e18 * 120 * 120 * 120 / 100 / 100 / 100);
        vm.stopPrank();

        vm.startPrank(carol);
        carolRewards = vote.withdrawRewards();
        assertEq(carolRewards, 24e18, "Incorrect carol rewards");
        // carol missed 1 epoch on redelegation
        assertEq(vote.balanceOf(carol), 100e18 * 120 * 120 / 100 / 100);
        vm.stopPrank();

        // Main assumption of our voting system
        assertEq(
            vote.getVotes(bob),
            vote.balanceOf(bob) + vote.balanceOf(alice) + vote.balanceOf(carol),
            "Incorrect bob votes"
        );
    }

    function test_UsersVoteInflationForMultipleEpochsWithTransfers() public {
        // epoch - set up proposals
        (uint256 proposal1Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 1");

        /// EPOCH 1

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        assertEq(vote.getVotes(alice), 120e18);
        vm.stopPrank();

        vm.startPrank(bob);
        vote.transfer(alice, 10e18);
        assertEq(vote.getVotes(alice), 130e18);
        vote.transfer(carol, 10e18);
        assertEq(vote.getVotes(carol), 110e18);
        // bob votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // we account for min (balance at the start of epoch,  at the moment of voting)
        assertEq(vote.getVotes(bob), 96e18);
        vm.stopPrank();

        vm.startPrank(carol);
        // carol votes on proposal 1
        governor.castVote(proposal1Id, yesVote);
        // carol gets 20 reward for voting, bob new voting power is not accounted for
        assertEq(vote.getVotes(carol), 130e18, "incorrect carol votes");
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 20e18, "Incorrect alice rewards");
        assertEq(vote.balanceOf(alice), 130e18);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 16e18, "Incorrect bob rewards");
        assertEq(vote.balanceOf(bob), 96e18);
        vm.stopPrank();

        vm.startPrank(carol);
        uint256 carolRewards = vote.withdrawRewards();
        assertEq(carolRewards, 20e18, "Incorrect carol rewards");
        assertEq(vote.balanceOf(alice), 130e18);
        vm.stopPrank();

        // Main invariant of system
        assertEq(
            vote.getVotes(alice) + vote.getVotes(bob) + vote.getVotes(carol),
            vote.balanceOf(alice) + vote.balanceOf(bob) + vote.balanceOf(carol),
            "Incorrect total votes and balances"
        );

        // Attempt to claim again - no rewards
        vm.startPrank(alice);
        aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 0, "Incorrect alice rewards");
        vm.stopPrank();

        vm.startPrank(bob);
        bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 0, "Incorrect bob rewards");
        vm.stopPrank();

        vm.startPrank(carol);
        carolRewards = vote.withdrawRewards();
        assertEq(carolRewards, 0, "Incorrect carol rewards");
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        /// EPOCH 2

        (uint256 proposal2Id,,,,) = proposeAddingNewListToSpog("Add new list to spog 2");

        // voting period started
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.startPrank(alice);
        // alice votes on proposal 2
        governor.castVote(proposal2Id, yesVote);
        assertEq(vote.getVotes(alice), 156e18);
        aliceRewards = vote.withdrawRewards();
        assertEq(aliceRewards, 26e18, "Incorrect alice rewards");
        vm.stopPrank();

        vm.startPrank(bob);
        // bob votes on proposal 2
        governor.castVote(proposal2Id, yesVote);
        bobRewards = vote.withdrawRewards();
        assertEq(bobRewards, 192e17, "Incorrect bob rewards");
        assertEq(vote.getVotes(bob), 1152e17);
        vm.stopPrank();

        vm.startPrank(carol);
        // carol votes on proposal 2
        governor.castVote(proposal2Id, yesVote);
        assertEq(vote.getVotes(carol), 156e18);
        carolRewards = vote.withdrawRewards();
        assertEq(carolRewards, 26e18, "Incorrect carol rewards");
        vm.stopPrank();

        // Main invariant of system
        assertEq(
            vote.getVotes(alice) + vote.getVotes(bob) + vote.getVotes(carol),
            vote.balanceOf(alice) + vote.balanceOf(bob) + vote.balanceOf(carol),
            "Incorrect total votes and balances"
        );
    }

}
