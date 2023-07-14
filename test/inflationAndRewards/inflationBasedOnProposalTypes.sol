// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "../../src/interfaces/ISPOG.sol";
import { IAccessControl } from "../interfaces/ImportedInterfaces.sol";

import { VOTE } from "../../src/tokens/VOTE.sol";
import { DualGovernor } from "../../src/core/governor/DualGovernor.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract InflationPerProposalTypeTest is SPOGBaseTest {
    function test_Inflation_EpochWithEmergencyAndStandardProposals() public {
        // set up proposals
        (uint256 proposal1Id, , , , ) = proposeEmergencyAppend(alice);
        (uint256 proposal2Id, , , , ) = proposeAddingNewListToSpog("Add new list to spog");

        // voting period started
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // alice is its own delegate
        uint256 aliceVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        uint256 aliceVotesAfterFirstVote = vote.getVotes(alice);
        assertEq(aliceVotesAfterFirstVote, aliceVotes, "No voting power rewards for emergency proposal");

        governor.castVote(proposal2Id, yesVote);

        uint256 aliceVotesAfterSecondVote = vote.getVotes(alice);
        assertEq(
            aliceVotesAfterSecondVote,
            aliceVotes + (spog.inflator() * aliceVotes) / 100,
            "No voting power rewards for emergency proposal"
        );

        // check non-zero inflation rewards
        uint256 rewards = vote.withdrawRewards();
        assertEq(rewards, (aliceStartBalance * spog.inflator()) / 100, "No inflation rewards");
    }

    function test_Inflation_EpochWithDoubleQuorumProposal() public {
        // set up proposals
        (uint256 proposal1Id, , , , ) = proposeTaxRangeChange("test proposal");

        // voting period started
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // alice is its own delegate
        uint256 aliceStartVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceStartVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        uint256 aliceVotes = vote.getVotes(alice);

        assertEq(
            aliceVotes,
            aliceStartVotes + (spog.inflator() * aliceStartVotes) / 100,
            "No voting power rewards for emergency proposal"
        );

        // check non-zero inflation rewards
        uint256 rewards = vote.withdrawRewards();
        assertEq(rewards, (aliceStartBalance * spog.inflator()) / 100, "No inflation rewards");
    }

    function test_NoInflation_EpochWithEmergencyAndResetProposals() public {
        // set up proposals
        (uint256 proposal1Id, , , , ) = proposeEmergencyAppend(alice);
        (uint256 proposal2Id, , , , ) = proposeReset("Reset proposal", address(cash));

        // voting period started
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // alice is its own delegate
        uint256 aliceStartVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceStartVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on emergency proposal
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        uint256 aliceVotes = vote.getVotes(alice);
        assertEq(aliceVotes, aliceStartVotes, "No voting power rewards for emergency proposal");

        // alice votes on reset proposal
        governor.castVote(proposal2Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        aliceVotes = vote.getVotes(alice);
        assertEq(aliceVotes, aliceStartVotes, "No voting power rewards for reset proposal");

        // no inflation rewards
        uint256 rewards = vote.withdrawRewards();
        assertEq(rewards, 0, "No inflation rewards");
    }
}
