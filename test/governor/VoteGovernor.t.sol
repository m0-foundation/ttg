// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import "forge-std/console.sol";

contract VoteSPOGGovernorTest is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    address carol = createUser("carol");

    uint256 spogVoteAmountToMint = 1000e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

    event NewSingleQuorumProposal(uint256 indexed proposalId);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /**
     * Helpers
     */
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

        // create new proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        expectEmit();
        emit NewSingleQuorumProposal(proposalId);
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

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

    /**
     * Test Functions
     */
    function test_Revert_Propose_WhenCalledNotBySPOG() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // revert when called not by SPOG, execute methods are closed to the public
        vm.expectRevert(abi.encodeWithSelector(SPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        voteGovernor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Execute_WhenCalledNotBySPOG() public {
        // propose adding a new list to spog
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("Add new list to spog");

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        // revert when called not by SPOG, execute methods are closed to the public
        vm.expectRevert(abi.encodeWithSelector(SPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        voteGovernor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_Revert_registerEmergencyProposal_WhenCalledNotBySPOG() public {
        vm.expectRevert(abi.encodeWithSelector(SPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        voteGovernor.registerEmergencyProposal(1);
    }

    function test_StartOfNextVotingPeriod() public {
        uint256 votingPeriod = voteGovernor.votingPeriod();
        uint256 startOfNextVotingPeriod = voteGovernor.startOfNextVotingPeriod();

        assertTrue(startOfNextVotingPeriod > block.number);
        assertEq(startOfNextVotingPeriod, block.number + votingPeriod);
    }

    function test_AccurateIncrementOfCurrentVotingPeriodEpoch() public {
        uint256 currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();

        assertEq(currentVotingPeriodEpoch, 0); // initial value

        for (uint256 i = 0; i < 6; i++) {
            vm.roll(block.number + voteGovernor.votingDelay() + 1);

            voteGovernor.inflateVotingTokens();
            currentVotingPeriodEpoch = voteGovernor.currentVotingPeriodEpoch();

            assertEq(currentVotingPeriodEpoch, i + 1);
        }
    }

    function test_CanOnlyVoteOnAProposalAfterItsVotingDelay() public {
        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // spogVote balance of voter valid for voting
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVote(proposalId, yesVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // check that proposal has 1 vote
        (uint256 proposalNoVotes, uint256 proposalYesVotes) = voteGovernor.proposalVotes(proposalId);

        console.log("proposalNoVotes: ", proposalNoVotes);
        console.log("proposalYesVotes: ", proposalYesVotes);

        assertEq(proposalYesVotes, spogVoteBalance, "Proposal does not have expected yes vote");
        assertEq(proposalNoVotes, 0, "Proposal does not have 0 no vote");
    }

    function test_CanVoteOnMultipleProposalsAfterItsVotingDelay() public {
        /**
         * Proposal 1 and 2 *********
         */
        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        // spogVote balance of voter
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVote(proposalId, yesVote);

        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVote(proposalId2, noVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

        assertTrue(
            voteGovernor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);
        voteGovernor.castVote(proposalId2, noVote);

        // check that proposal has 1 vote
        (uint256 noVotes, uint256 yesVotes) = voteGovernor.proposalVotes(proposalId);
        (uint256 noVotes2, uint256 yesVotes2) = voteGovernor.proposalVotes(proposalId2);

        assertEq(yesVotes, spogVoteBalance, "Proposal does not have expected yes vote");
        assertEq(noVotes, 0, "Proposal does not have 0 no vote");

        assertEq(noVotes2, spogVoteBalance, "Proposal2 does not have expected no vote");
        assertEq(yesVotes2, 0, "Proposal2 does not have 0 yes vote");

        /**
         * Proposal 3 *********
         */
        // Add another proposal and voting can only happen after vote delay
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // spogVote balance of voter before casting vote on proposal 3
        uint256 spogVoteBalanceForProposal3 = spogVote.balanceOf(address(this));

        // vm.expectRevert("Governor: vote not currently active");
        // voteGovernor.castVote(proposalId3, noVote);

        assertTrue(
            voteGovernor.state(proposalId3) == IGovernor.ProposalState.Pending, "Proposal3 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId3, noVote);

        (uint256 noVotes3, uint256 yesVotes3) = voteGovernor.proposalVotes(proposalId3);

        assertEq(noVotes3, spogVoteBalanceForProposal3, "Proposal3 does not have expected no vote");
        assertEq(yesVotes3, 0, "Proposal3 does not have 0 yes vote");
    }

    function test_UsersGetsVoteTokenInflationAfterVotingOnInAllProposals() public {
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

        uint256 relevantEpochProposals = voteGovernor.currentVotingPeriodEpoch() + 1;

        // epochProposalsCount for epoch 0 should be 3
        assertEq(voteGovernor.epochProposalsCount(relevantEpochProposals), 3, "current epoch should have 3 proposals");

        // cannot vote in epoch 0
        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVote(proposalId, yesVote);

        // balance of spogVote for vault should be 0
        uint256 spogVoteBalanceForVaultForEpochZero = spogVote.balanceOf(address(vault));
        assertEq(spogVoteBalanceForVaultForEpochZero, 0, "vault should have 0 spogVote balance");

        // voting period started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        vm.prank(address(voteGovernor));
        uint256 epochInflation = spog.tokenInflationCalculation();

        // alice votes on proposal 1
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        uint256 spogVoteBalanceForVaultForEpochOne = spogVote.balanceOf(address(vault));
        assertGt(
            spogVoteBalanceForVaultForEpochOne,
            spogVoteBalanceForVaultForEpochZero,
            "vault should have more spogVote balance"
        );

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
        assertEq(spogVote.balanceOf(alice), spogVoteAmountToMint, "Alice should have same spogVote balance");
        assertEq(spogVote.balanceOf(bob), spogVoteAmountToMint, "Bob should have same spogVote balance");

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
            vault.hasClaimedVoteTokenRewardsForEpoch(alice, relevantEpochProposals),
            "Alice should not have claimed vote token rewards"
        );
        assertFalse(
            vault.hasClaimedVoteTokenRewardsForEpoch(bob, relevantEpochProposals),
            "Bob should not have claimed vote token rewards"
        );

        // alice and bob withdraw their vote token inflation rewards from Vault during current epoch. They must do so to get the rewards
        vm.startPrank(alice);
        vault.withdrawVoteTokenRewards();
        vm.stopPrank();

        vm.startPrank(bob);
        vault.withdrawVoteTokenRewards();
        vm.stopPrank();

        assertTrue(
            vault.hasClaimedVoteTokenRewardsForEpoch(alice, relevantEpochProposals),
            "Alice should have claimed vote token rewards"
        );
        assertTrue(
            vault.hasClaimedVoteTokenRewardsForEpoch(bob, relevantEpochProposals),
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
        vault.withdrawVoteTokenRewards();

        vm.stopPrank();

        // carol voted in 1 proposal
        assertEq(
            voteGovernor.accountEpochNumProposalsVotedOn(carol, relevantEpochProposals),
            1,
            "Carol should have voted 1 times in epoch 1"
        );

        // voting epoch 1 finished, epoch 2 started
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        voteGovernor.inflateVotingTokens();

        // carol remains with the same balance
        assertEq(spogVote.balanceOf(carol), spogVoteAmountToMint, "Carol should have same spogVote balance");

        // vault should have received the remaining inflationary rewards from epoch 1
        assertGt(
            spogVote.balanceOf(address(vault)),
            spogVoteBalanceForVaultForEpochZero,
            "vault should have received the remaining inflationary rewards from epoch 1"
        );
    }

    function test_CanBatchVoteOnMultipleProposalsAfterItsVotingDelay() public {
        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        uint256[] memory proposals = new uint256[](2);
        proposals[0] = proposalId;
        proposals[1] = proposalId2;

        uint8[] memory support = new uint8[](2);
        support[0] = yesVote;
        support[1] = noVote;

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        voteGovernor.castVotes(proposals, support);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

        assertTrue(
            voteGovernor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposals
        voteGovernor.castVotes(proposals, support);

        // check that proposal has 1 vote
        (uint256 noVotes, uint256 yesVotes) = voteGovernor.proposalVotes(proposalId);
        (uint256 noVotes2, uint256 yesVotes2) = voteGovernor.proposalVotes(proposalId2);

        // spogVote balance of voter
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        assertTrue(yesVotes == spogVoteBalance, "Proposal does not have expected yes vote");
        assertTrue(noVotes == 0, "Proposal does not have 0 no vote");

        assertTrue(noVotes2 == spogVoteBalance, "Proposal2 does not have expected no vote");
        assertTrue(yesVotes2 == 0, "Proposal2 does not have 0 yes vote");
    }

    function test_VoteTokenSupplyInflatesAtTheBeginningOfEachVotingPeriod() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        uint256 spogVoteSupplyBefore = spogVote.totalSupply();

        uint256 vaultVoteTokenBalanceBefore = spogVote.balanceOf(address(vault));

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        voteGovernor.castVote(proposalId, yesVote);

        uint256 spogVoteSupplyAfterFirstPeriod = spogVote.totalSupply();
        uint256 amountAddedByInflation = (spogVoteSupplyBefore * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterFirstPeriod,
            spogVoteSupplyBefore + amountAddedByInflation,
            "Vote token supply didn't inflate correctly"
        );

        // check that vault has received the vote inflationary supply
        uint256 vaultVoteTokenBalanceAfterFirstPeriod = spogVote.balanceOf(address(vault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstPeriod,
            vaultVoteTokenBalanceBefore + amountAddedByInflation,
            "Vault did not receive the accurate vote inflationary supply"
        );

        // start of new wpoch inflation is triggered
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        uint256 spogVoteSupplyAfterSecondPeriod = spogVote.totalSupply();
        uint256 amountAddedByInflation2 = (spogVoteSupplyAfterFirstPeriod * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterSecondPeriod,
            spogVoteSupplyAfterFirstPeriod + amountAddedByInflation2,
            "Vote token supply didn't inflate correctly in the second period"
        );
    }

    function test_ProposalsShouldBeAllowedAfterInactiveEpoch() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        voteGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // fast forward 5 epochs
        vm.roll(block.number + 5 * voteGovernor.votingDelay() + 1);

        // should not revert
        proposeAddingNewListToSpog("new list to spog 2");
    }
}
