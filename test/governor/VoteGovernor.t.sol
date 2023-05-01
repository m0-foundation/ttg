// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import "forge-std/console.sol";

contract VoteSPOGGovernorTest is SPOG_Base {
    address alice = createUser("alice");

    uint8 noVote = 0;
    uint8 yesVote = 1;

    event NewVoteQuorumProposal(uint256 indexed proposalId);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

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

        // create new proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        expectEmit();
        emit NewVoteQuorumProposal(proposalId);
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

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

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

    function test_Revert_turnOnAndOffEmergencyVoting_WhenCalledNotBySPOG() public {
        vm.expectRevert(abi.encodeWithSelector(SPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        voteGovernor.turnOnEmergencyVoting();

        vm.expectRevert(abi.encodeWithSelector(SPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        voteGovernor.turnOffEmergencyVoting();
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
        vm.roll(block.number + deployScript.time() + 1);

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
        uint256 startOfNextEpoch = voteGovernor.startOfNextEpoch();

        assertTrue(startOfNextEpoch > block.number);
        assertEq(startOfNextEpoch, block.number + votingPeriod);
    }

    function test_AccurateIncrementOfCurrentVotingPeriodEpoch() public {
        uint256 currentEpoch = voteGovernor.currentEpoch();

        assertEq(currentEpoch, 0); // initial value

        for (uint256 i = 0; i < 6; i++) {
            vm.roll(block.number + voteGovernor.votingDelay() + 1);

            currentEpoch = voteGovernor.currentEpoch();

            assertEq(currentEpoch, i + 1);
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
        // Proposal 1 and 2

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

        // Proposal 3

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
        // epoch 0
        uint256 spogVoteSupplyBefore = spogVote.totalSupply();
        uint256 vaultVoteTokenBalanceBefore = spogVote.balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        uint256 spogVoteSupplyAfterInflation1 = spogVote.totalSupply();
        uint256 amountAddedByInflation = (spogVoteSupplyBefore * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterInflation1,
            spogVoteSupplyBefore + amountAddedByInflation,
            "Vote token supply didn't inflate correctly"
        );

        // check that vault has received the vote inflationary supply
        uint256 vaultVoteTokenBalanceAfterInflation1 = spogVote.balanceOf(address(vault));
        assertEq(
            vaultVoteTokenBalanceAfterInflation1,
            vaultVoteTokenBalanceBefore + amountAddedByInflation,
            "Vault did not receive the accurate vote inflationary supply"
        );

        // fast forward to an active voting period. epoch 1
        vm.roll(block.number + voteGovernor.votingDelay() + 1);
        voteGovernor.castVote(proposalId, yesVote);

        uint256 spogVoteSupplyAfterVoting = spogVote.totalSupply();

        assertEq(spogVoteSupplyAfterInflation1, spogVoteSupplyAfterVoting, "Vote token supply got inflated by voting");

        // start of new epoch 2
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);
        uint256 spogVoteSupplyAfterExecution = spogVote.totalSupply();

        assertEq(
            spogVoteSupplyAfterInflation1, spogVoteSupplyAfterExecution, "Vote token supply got inflated by execution"
        );

        // new proposal, inflate supply
        proposeAddingNewListToSpog("new list to spog, again");

        uint256 spogVoteSupplyAfterInflation2 = spogVote.totalSupply();
        uint256 amountAddedByInflation2 = (spogVoteSupplyAfterInflation1 * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterInflation2,
            spogVoteSupplyAfterInflation1 + amountAddedByInflation2,
            "Vote token supply didn't inflate correctly during the second inflation"
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
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // fast forward 5 epochs
        vm.roll(block.number + 5 * voteGovernor.votingDelay() + 1);

        // should not revert
        proposeAddingNewListToSpog("new list to spog 2");
    }

    function test_turnOnAndOffEmergencyVoting() public {
        uint256 governorVotingDelay = voteGovernor.votingDelay();
        vm.startPrank(address(spog));

        // turn on emergency voting and check that voting delay is minimum now
        voteGovernor.turnOnEmergencyVoting();
        assertEq(voteGovernor.votingDelay(), voteGovernor.MINIMUM_VOTING_DELAY(), "emergency voting should be on");

        // turn off emergency voting and check that voting delay is reset back
        voteGovernor.turnOffEmergencyVoting();
        assertEq(voteGovernor.votingDelay(), governorVotingDelay, "emergency voting should be off");
    }
}
