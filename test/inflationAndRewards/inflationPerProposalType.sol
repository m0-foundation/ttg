// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract InflationPerProposalTypeTest is SPOGBaseTest {
    function test_Inflation_EpochWithEmergencyAndStandardProposals() public {
        // set up proposals
        (uint256 proposal1Id, , , , ) = proposeEmergencyAppend(alice);
        (uint256 proposal2Id, , , , ) = proposeAddingAnAddressToList(bob);

        vm.roll(block.number + 2);

        // alice votes on proposal 1
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        // alice is its own delegate
        uint256 aliceVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes didn't change, no inflation of voting power
        uint256 aliceVotesAfterFirstVote = vote.getVotes(alice);
        assertEq(aliceVotesAfterFirstVote, aliceVotes, "No voting power inflation for emergency proposal");

        // voting period for standard proposal has started
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);
        governor.castVote(proposal2Id, yesVote);

        uint256 aliceVotesAfterSecondVote = vote.getVotes(alice);
        assertEq(
            aliceVotesAfterSecondVote,
            aliceVotes + (spog.inflator() * aliceVotes) / 100,
            "No voting power inflation for emergency proposal"
        );

        // check non-zero inflation
        uint256 inflation = vote.claimInflation();
        assertEq(inflation, (aliceStartBalance * spog.inflator()) / 100, "No inflation");
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
            "No voting power inflation for emergency proposal"
        );

        // check non-zero inflation
        uint256 inflation = vote.claimInflation();
        assertEq(inflation, (aliceStartBalance * spog.inflator()) / 100, "No inflation");
    }

    function test_NoInflation_EpochWithEmergencyAndResetProposals() public {
        // set up proposals
        (uint256 proposal1Id, , , , ) = proposeEmergencyAppend(alice);
        (uint256 proposal2Id, , , , ) = proposeReset("Reset proposal", address(cash));

        // emergency proposals voting period has started
        vm.roll(block.number + 2);

        // alice is its own delegate
        uint256 aliceStartVotes = vote.getVotes(alice);
        uint256 aliceStartBalance = vote.balanceOf(alice);
        assertEq(aliceStartBalance, aliceStartVotes, "Votes and balances are equal, alice uses self-delegation");

        // alice votes on emergency proposal
        vm.startPrank(alice);
        governor.castVote(proposal1Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        uint256 aliceVotes = vote.getVotes(alice);
        assertEq(aliceVotes, aliceStartVotes, "No voting power inflation for emergency proposal");

        // alice votes on reset proposal
        governor.castVote(proposal2Id, yesVote);

        // alice votes didn't change, no inflation of voting power
        aliceVotes = vote.getVotes(alice);
        assertEq(aliceVotes, aliceStartVotes, "No voting power inflation for reset proposal");

        // no inflation
        uint256 inflation = vote.claimInflation();
        assertEq(inflation, 0, "No inflation");
    }
}
