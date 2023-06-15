// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract VoteSPOGGovernorTest is SPOG_Base {
    uint256 signerPrivateKey = 0xA11CE;
    address signer = vm.addr(signerPrivateKey);

    event NewVoteQuorumProposal(uint256 indexed proposalId);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // calculate vote token inflation rewards for voter
    function calculateVoteTokenInflationRewardsForVoter(
        address voter,
        uint256 proposalId,
        uint256 amountToBeSharedOnProRataBasis
    ) private view returns (uint256) {
        uint256 accountVotingTokenBalance = governor.getVotes(voter, governor.proposalSnapshot(proposalId));

        uint256 totalVotingTokenSupplyApplicable = vote.totalSupply() - amountToBeSharedOnProRataBasis;

        uint256 percentageOfTotalSupply = accountVotingTokenBalance * 100 / totalVotingTokenSupplyApplicable;

        uint256 inflationRewards = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        return inflationRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StartOfNextVotingPeriod() public {
        uint256 votingPeriod = governor.votingPeriod();
        uint256 startOfNextEpoch = governor.startOf(governor.currentEpoch() + 1);

        assertTrue(startOfNextEpoch > block.number);
        assertEq(startOfNextEpoch, block.number + votingPeriod);
    }

    function test_AccurateIncrementOfCurrentVotingPeriodEpoch() public {
        uint256 currentEpoch = governor.currentEpoch();

        assertEq(currentEpoch, 0); // initial value

        for (uint256 i = 0; i < 6; i++) {
            vm.roll(block.number + governor.votingDelay() + 1);

            currentEpoch = governor.currentEpoch();

            assertEq(currentEpoch, i + 1);
        }
    }

    function test_CanOnlyVoteOnAProposalAfterItsVotingDelay() public {
        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // vote balance of voter valid for voting
        uint256 voteBalance = vote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("DualGovernor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check that proposal has 1 vote
        (uint256 proposalNoVotes, uint256 proposalYesVotes) = governor.proposalVotes(proposalId);

        assertEq(proposalYesVotes, voteBalance, "Proposal does not have expected yes vote");
        assertEq(proposalNoVotes, 0, "Proposal does not have 0 no vote");
    }

    function test_CanVoteOnMultipleProposalsAfterItsVotingDelay() public {
        // Proposal 1 and 2

        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        // vote balance of voter
        uint256 voteBalance = vote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("DualGovernor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        vm.expectRevert("DualGovernor: vote not currently active");
        governor.castVote(proposalId2, noVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

        assertTrue(
            governor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        governor.castVote(proposalId2, noVote);

        // check that proposal has 1 vote
        (uint256 noVotes, uint256 yesVotes) = governor.proposalVotes(proposalId);
        (uint256 noVotes2, uint256 yesVotes2) = governor.proposalVotes(proposalId2);

        assertEq(yesVotes, voteBalance, "Proposal does not have expected yes vote");
        assertEq(noVotes, 0, "Proposal does not have 0 no vote");

        assertEq(noVotes2, voteBalance, "Proposal2 does not have expected no vote");
        assertEq(yesVotes2, 0, "Proposal2 does not have 0 yes vote");

        // Proposal 3

        // Add another proposal and voting can only happen after vote delay
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // vote balance of voter before casting vote on proposal 3
        uint256 voteBalanceForProposal3 = vote.balanceOf(address(this));

        // vm.expectRevert("Governor: vote not currently active");
        // governor.castVote(proposalId3, noVote);

        assertTrue(
            governor.state(proposalId3) == IGovernor.ProposalState.Pending, "Proposal3 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId3, noVote);

        (uint256 noVotes3, uint256 yesVotes3) = governor.proposalVotes(proposalId3);

        assertEq(noVotes3, voteBalanceForProposal3, "Proposal3 does not have expected no vote");
        assertEq(yesVotes3, 0, "Proposal3 does not have 0 yes vote");
    }

    function test_VoteTokenSupplyInflatesAtTheBeginningOfEachVotingPeriod() public {
        // epoch 0
        uint256 voteSupplyBefore = vote.totalSupply();
        uint256 vaultVoteTokenBalanceBefore = vote.balanceOf(address(voteVault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        uint256 voteSupplyAfterFirstInflation = vote.totalSupply();
        uint256 amountAddedByInflation = (voteSupplyBefore * deployScript.inflator()) / 100;

        assertEq(
            voteSupplyAfterFirstInflation,
            voteSupplyBefore + amountAddedByInflation,
            "Vote token supply didn't inflate correctly"
        );

        // check that vault has received the vote inflationary supply
        uint256 vaultVoteTokenBalanceAfterFirstInflation = vote.balanceOf(address(voteVault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstInflation,
            vaultVoteTokenBalanceBefore + amountAddedByInflation,
            "Vault did not receive the accurate vote inflationary supply"
        );

        // fast forward to an active voting period. epoch 1
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, yesVote);

        vm.prank(bob);
        governor.castVote(proposalId, yesVote);

        vm.prank(charlie);
        governor.castVote(proposalId, yesVote);

        uint256 voteSupplyAfterVoting = vote.totalSupply();

        assertEq(voteSupplyAfterFirstInflation, voteSupplyAfterVoting, "Vote token supply got inflated by voting");

        // start of new epoch 2
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
        uint256 voteSupplyAfterExecution = vote.totalSupply();

        assertEq(voteSupplyAfterFirstInflation, voteSupplyAfterExecution, "Vote token supply got inflated by execution");

        // new proposal, inflate supply
        proposeAddingNewListToSpog("new list to spog, again");

        uint256 voteSupplyAfterSecondInflation = vote.totalSupply();
        uint256 amountAddedBySecondInflation = (voteSupplyAfterFirstInflation * deployScript.inflator()) / 100;

        assertEq(
            voteSupplyAfterSecondInflation,
            voteSupplyAfterFirstInflation + amountAddedBySecondInflation,
            "Vote token supply didn't inflate correctly during the second inflation"
        );
    }

    function test_ValueTokenSupplyDoesNotInflateAtTheBeginningOfEachVotingPeriodWithoutActivity() public {
        uint256 valueSupplyBefore = value.totalSupply();

        uint256 vaultVoteTokenBalanceBefore = value.balanceOf(address(voteVault));

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 valueSupplyAfterFirstPeriod = value.totalSupply();

        assertEq(valueSupplyAfterFirstPeriod, valueSupplyBefore, "Vote token supply inflated incorrectly");

        // check that vault has received the vote inflationary supply
        // TODO: clean up names here
        uint256 vaultVoteTokenBalanceAfterFirstPeriod = value.balanceOf(address(voteVault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstPeriod,
            vaultVoteTokenBalanceBefore,
            "Vault received an inaccurate vote inflationary supply"
        );

        // start of new epoch inflation is triggered
        vm.roll(block.number + governor.votingPeriod() + 1);

        uint256 valueSupplyAfterSecondPeriod = value.totalSupply();

        assertEq(
            valueSupplyAfterSecondPeriod,
            valueSupplyAfterFirstPeriod,
            "Vote token supply inflated incorrectly in the second period"
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
        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, yesVote);

        vm.prank(bob);
        governor.castVote(proposalId, yesVote);

        vm.prank(charlie);
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // fast forward 5 epochs
        vm.roll(block.number + 5 * governor.votingDelay() + 1);

        // should not revert
        proposeAddingNewListToSpog("new list to spog 2");
    }

    function test_Revert_Propose_WhenMoreThanOneProposalPassed() public {
        // set data for 2 proposals at once
        address[] memory targets = new address[](2);
        targets[0] = address(spog);
        targets[1] = address(spog);
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", alice, list);
        calldatas[1] = abi.encodeWithSignature("append(address,address)", bob, list);
        string memory description = "add 2 merchants to spog";

        // approve cash spend for proposal
        cash.approve(address(spog), tax);

        // revert when method is not supported
        vm.expectRevert(IDualGovernor.TooManyTargets.selector);
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenEtherValueIsPassed() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        cash.approve(address(spog), tax);

        // revert when proposal expects ETH value
        vm.expectRevert(IDualGovernor.InvalidValue.selector);
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenTargetIsNotSPOG() public {
        address[] memory targets = new address[](1);
        // Instead of SPOG, we are passing the list contract
        targets[0] = address(list);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        cash.approve(address(spog), tax);

        // revert when proposal has invalid target
        vm.expectRevert(IDualGovernor.InvalidTarget.selector);
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenMethodIsNotSupported() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addListFun(address)", list);
        string memory description = "Should not pass proposal";

        // approve cash spend for proposal
        cash.approve(address(spog), tax);
        // revert when method signature is not supported
        vm.expectRevert(IDualGovernor.InvalidMethod.selector);
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_SameProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        cash.approve(address(spog), tax);

        // propose
        governor.propose(targets, values, calldatas, description);

        cash.approve(address(spog), tax);
        vm.expectRevert("Governor: proposal already exists");
        governor.propose(targets, values, calldatas, description);
    }
}
