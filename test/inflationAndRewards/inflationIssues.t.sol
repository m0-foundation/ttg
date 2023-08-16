// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IDualGovernorQuorum } from "../../src/governor/IDualGovernor.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

import "forge-std/console.sol";

contract InflationTest is SPOGBaseTest {
    function test_0x52_issue() public {
        // epoch - set up proposals
        (uint256 proposal1Id, , , , ) = proposeAddingAnAddressToList(makeAddr("Alpha"));

        address delegatee = createUser("delegatee");

        vm.prank(alice);
        vote.delegate(delegatee);

        // voting period started
        // TODO no +1 here
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        vm.prank(alice);
        vote.delegate(alice);

        vm.prank(bob);
        vote.delegate(delegatee);

        uint256 delegateeVotesBeforeVoting = vote.getVotes(delegatee);

        vm.prank(delegatee);
        governor.castVote(proposal1Id, yesVote);

        assertEq(vote.getVotes(delegatee), delegateeVotesBeforeVoting, "Incorrect inflation of voting power");

        vm.prank(alice);
        uint256 aliceInflation = vote.claimInflation();
        assertEq(aliceInflation, 0, "No inflation for alice");

        vm.prank(bob);
        uint256 bobInflation = vote.claimInflation();
        assertEq(bobInflation, 0, "No inflation for bob");
    }

    function test_0x52_issue_transfers() public {
        // epoch - set up proposals
        (uint256 proposal1Id, , , , ) = proposeAddingAnAddressToList(makeAddr("Alpha"));

        address delegatee = createUser("delegatee");

        vm.prank(alice);
        vote.delegate(delegatee);

        // voting period started
        // TODO no +1 here
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        uint256 aliceBalance = vote.balanceOf(alice);
        vm.prank(alice);
        vote.transfer(carol, aliceBalance);

        vm.prank(bob);
        vote.delegate(delegatee);

        uint256 delegateeVotesBeforeVoting = vote.getVotes(delegatee);

        vm.prank(delegatee);
        governor.castVote(proposal1Id, yesVote);

        vm.prank(carol);
        governor.castVote(proposal1Id, yesVote);

        assertEq(vote.getVotes(delegatee), delegateeVotesBeforeVoting, "Incorrect inflation of voting power");

        vm.prank(alice);
        uint256 aliceInflation = vote.claimInflation();
        assertEq(aliceInflation, 0, "No inflation for alice");

        vm.prank(bob);
        uint256 bobInflation = vote.claimInflation();
        assertEq(bobInflation, 0, "No inflation for bob");

        vm.prank(carol);
        uint256 carolInflation = vote.claimInflation();
        assertEq(carolInflation, 20e18, "Wrong inflation for carol");
    }

    function test_inflationStuckInDelegate() external {
        address david = createUser("david");

        assertEq(vote.balanceOf(alice), 100e18, "alice starting balance incorrect");
        assertEq(vote.balanceOf(bob), 100e18, "bob starting balance incorrect");
        assertEq(vote.balanceOf(david), 0, "david starting balance incorrect");

        assertEq(vote.getVotes(alice), 100e18, "alice starting votes incorrect");
        assertEq(vote.getVotes(bob), 100e18, "bob starting votes incorrect");
        assertEq(vote.getVotes(david), 0, "david starting votes incorrect");

        // Alice delegate's to David in this epoch.
        vm.prank(alice);
        vote.delegate(david);

        // A proposal is created this epoch.
        (uint256 proposalId, , , , ) = proposeAddingAnAddressToList(makeAddr("Alpha"));

        // The next epoch begins, such that votes for the proposal can be collected.
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // Alice delegate's to herself in this epoch.
        vm.prank(alice);
        vote.delegate(alice);

        // Bob delegate's to David in this epoch.
        vm.prank(bob);
        vote.delegate(david);

        // David votes for the proposal.
        vm.prank(david);
        governor.castVote(proposalId, yesVote);

        // The next epoch begins, such that the proposal can be executed.
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // Everyone claim's inflation.
        vm.prank(alice);
        vote.claimInflation();

        vm.prank(bob);
        vote.claimInflation();

        vm.prank(david);
        vote.claimInflation();

        assertEq(vote.balanceOf(alice), 100e18, "alice balance incorrect after votes and claims");
        assertEq(vote.balanceOf(bob), 100e18, "bob balance incorrect after votes and claims");
        assertEq(vote.balanceOf(david), 0, "david balance incorrect after votes and claims");

        assertEq(vote.getVotes(alice), 100e18, "alice votes incorrect after votes and claims");
        assertEq(vote.getVotes(bob), 0, "bob votes incorrect after votes and claims");
        assertEq(vote.getVotes(david), 100e18, "david votes incorrect after votes and claims");

        // The next epoch begins, just for the sake of it.
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // Bob delegate's to himself in this epoch.
        vm.prank(bob);
        vote.delegate(bob);

        // Everyone claim's inflation.
        vm.prank(alice);
        vote.claimInflation();

        vm.prank(bob);
        vote.claimInflation();

        vm.prank(david);
        vote.claimInflation();

        assertEq(vote.balanceOf(alice), 100e18, "alice balance incorrect at end");
        assertEq(vote.balanceOf(bob), 100e18, "bob balance incorrect at end");
        assertEq(vote.balanceOf(david), 0, "david balance incorrect at end");

        assertEq(vote.getVotes(alice), 100e18, "alice votes incorrect at end");
        assertEq(vote.getVotes(bob), 100e18, "bob votes incorrect at end");
        assertEq(vote.getVotes(david), 0e18, "david votes incorrect at end");
    }

    function test_0x52_issue_advanced() public {
        // epoch - set up proposals
        (uint256 proposal1Id, , , , ) = proposeAddingAnAddressToList(makeAddr("Alpha"));

        address david = createUser("david");
        vm.prank(david);
        vote.delegate(david);
        assertEq(vote.getVotes(david), 0, "david starting votes are incorrect");

        vm.prank(alice);
        vote.delegate(david);
        uint256 davidStartVotes = vote.getVotes(david);
        assertEq(davidStartVotes, vote.balanceOf(alice), "david votes are incorrect");

        // david has balance now, but votes remain the same. Alice is till delegated to David
        vm.prank(alice);
        vote.transfer(david, 50e18);
        assertEq(vote.getVotes(david), davidStartVotes, "david votes are incorrect");

        console.log("alice balance = ", vote.balanceOf(alice) / 1e18);
        console.log("david balance = ", vote.balanceOf(david) / 1e18);

        // voting period started
        // TODO no +1 here
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        vm.prank(alice);
        vote.transfer(david, 10e18);
        console.log("alice balance = ", vote.balanceOf(alice) / 1e18);
        console.log("david balance = ", vote.balanceOf(david) / 1e18);

        // alice - balance 40

        // vm.prank(david);
        // vote.transfer(carol, 30e18);

        // david - balance 20

        console.log("david votes = ", vote.getVotes(david) / 1e18);
        // assertEq(vote.getVotes(david), davidStartVotes - 30e18, "david votes are incorrect");

        vm.prank(david);
        governor.castVote(proposal1Id, yesVote);

        // uint256 votesSurplus = vote.getVotes(david) - davidStartVotes;
        console.log("david votes after voting = ", vote.getVotes(david) / 1e18);

        vm.prank(david);
        uint256 davidInflation = vote.claimInflation();
        console.log("david inflation = ", davidInflation / 1e18);

        vm.prank(alice);
        uint256 aliceInflation = vote.claimInflation();
        console.log("alice inflation = ", aliceInflation / 1e18);

        console.log("david votes after voting = ", vote.getVotes(david) / 1e18);

        // vm.prank(carol);
        // vote.transfer(david, 10e18);

        // vm.prank(david);
        // vote.transfer(carol, 5e18);

        // vm.prank(alice);
        // vote.delegate(alice);

        // vm.prank(bob);
        // vote.delegate(david);

        // vm.prank(carol);
        // vote.transfer(david, 10e18);

        // uint256 davidVotesBeforeVoting = vote.getVotes(david);

        // vm.prank(david);
        // governor.castVote(proposal1Id, yesVote);

        // vm.prank(carol);
        // governor.castVote(proposal1Id, yesVote);

        // assertEq(vote.getVotes(david), davidVotesBeforeVoting, "Incorrect inflation of voting power");

        // vm.prank(alice);
        // uint256 aliceInflation = vote.claimInflation();
        // assertEq(aliceInflation, 0, "No inflation for alice");

        // vm.prank(bob);
        // uint256 bobInflation = vote.claimInflation();
        // assertEq(bobInflation, 0, "No inflation for bob");

        // vm.prank(david);
        // uint256 davidInflation = vote.claimInflation();
        // assertEq(davidInflation, 0, "No inflation for david");

        // vm.prank(carol);
        // uint256 carolInflation = vote.claimInflation();
        // console.log("carol inflation = ", carolInflation);
        // // assertEq(carolInflation, 0e18, "Wrong inflation for carol");
    }
}
