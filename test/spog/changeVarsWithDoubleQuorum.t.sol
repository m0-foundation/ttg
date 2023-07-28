// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IGovernor } from "../interfaces/ImportedInterfaces.sol";

import { ISPOG } from "../../src/interfaces/ISPOG.sol";
import { ISPOGGovernor } from "../../src/interfaces/ISPOGGovernor.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_change is SPOGBaseTest {
    event Proposal(uint256 indexed epoch, uint256 indexed proposalId, ISPOGGovernor.ProposalType indexed proposalType);
    event TaxRangeChanged(uint256 oldLowerRange, uint256 newLowerRange, uint256 oldUpperRange, uint256 newUpperRange);
    event ValueQuorumNumeratorUpdated(uint256 oldValueQuorumNumerator, uint256 newValueQuorumNumerator);
    event VoteQuorumNumeratorUpdated(uint256 oldVoteQuorumNumerator, uint256 newVoteQuorumNumerator);

    address public charlie = createUser("charlie");

    function test_Revert_ChangeTaxRange_WhenNotCalledByGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.changeTaxRange(10e18, 12e18);
    }

    function test_Revert_Change_WhenValueHoldersDoNotVote() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 taxLowerBound = spog.taxLowerBound();
        uint256 taxUpperBound = spog.taxUpperBound();

        // give charlie vote power
        vote.mint(charlie, 95e18);
        vm.startPrank(charlie);
        vote.delegate(charlie);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 noVoteVotes, uint256 yesVoteVotes) = governor.proposalVotes(proposalId);
        (uint256 noValueVotes, uint256 yesValueVotes) = governor.proposalValueVotes(proposalId);

        assertTrue(yesVoteVotes == 95e18, "Yes vote votes should be charlie vote votes");
        assertTrue(noVoteVotes == 0, "No vote votes should be equal to 0");
        assertTrue(yesValueVotes == 0, "Yes value votes should be charlie value votes");
        assertTrue(noValueVotes == 0, "No value votes should be 0");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check that execute function is reverted if value quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that tax range has not been changed
        assertTrue(
            spog.taxLowerBound() == taxLowerBound && spog.taxUpperBound() == taxUpperBound,
            "Tax range should not have been changed"
        );
    }

    function test_Revert_Change_WhenVoteHoldersDoNotVote() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 taxLowerBound = spog.taxLowerBound();
        uint256 taxUpperBound = spog.taxUpperBound();

        // give charlie vote power
        value.mint(charlie, 95e18);
        vm.startPrank(charlie);
        value.delegate(charlie);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 noVoteVotes, uint256 yesVoteVotes) = governor.proposalVotes(proposalId);
        (uint256 noValueVotes, uint256 yesValueVotes) = governor.proposalValueVotes(proposalId);

        assertTrue(yesVoteVotes == 0, "Yes vote votes should be 0");
        assertTrue(noVoteVotes == 0, "No vote votes should be 0");
        assertTrue(yesValueVotes == 95e18, "Yes value votes should be 95e18");
        assertTrue(noValueVotes == 0, "No value votes should be 0");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check that execute function is reverted if value quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that tax range has not been changed
        assertTrue(
            spog.taxLowerBound() == taxLowerBound && spog.taxUpperBound() == taxUpperBound,
            "Tax range should not have been changed"
        );
    }

    function test_Revert_ChangeTaxRange_WhenVoteValueHoldersDoNotAgree() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, noVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertFalse(governor.state(proposalId) == IGovernor.ProposalState.Succeeded);

        // Check that execute function is reverted if vote quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_ChangeTaxRange_Success() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 oldTaxLowerBound = spog.taxLowerBound();
        uint256 oldTaxUpperBound = spog.taxUpperBound();

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        vm.startPrank(bob);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that TaxRangeChanged event was emitted
        expectEmit();
        emit TaxRangeChanged(oldTaxLowerBound, 10e18, oldTaxUpperBound, 12e18);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 newTaxLowerBound = spog.taxLowerBound();
        uint256 newTaxUpperBound = spog.taxUpperBound();

        // assert that tax range has been changed
        assertTrue(newTaxLowerBound == 10e18, "Tax range lower bound has not changed");
        assertTrue(newTaxUpperBound == 12e18, "Tax range upper bound has not changed");
    }

    function test_UpdateVoteQuorum_Success() public {
        // old and new value quorum numerator
        uint256 oldVoteQuorumNumerator = governor.voteQuorumNumerator();
        uint256 newVoteQuorumNumerator = 15;

        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("updateVoteQuorumNumerator(uint256)", newVoteQuorumNumerator);
        string memory description = "Change vote quorum numerator";
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        vm.startPrank(bob);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that VoteQuorumNumeratorUpdated event was emitted
        expectEmit();
        emit VoteQuorumNumeratorUpdated(oldVoteQuorumNumerator, newVoteQuorumNumerator);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 updatedVoteQuorumNumerator = governor.voteQuorumNumerator();
        assertEq(updatedVoteQuorumNumerator, newVoteQuorumNumerator, "Vote quorum numerator has not changed");
    }

    function test_UpdateValueQuorum_Success() public {
        // old and new value quorum numerator
        uint256 oldValueQuorumNumerator = governor.valueQuorumNumerator();
        uint256 newValueQuorumNumerator = 16;

        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("updateValueQuorumNumerator(uint256)", newValueQuorumNumerator);
        string memory description = "Change value quorum numerator";
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, noVote);

        require(
            vote.getVotes(alice) + vote.getVotes(bob) + vote.getVotes(carol) >= governor.voteQuorum(block.number),
            "not enough votes to reach quorum"
        );

        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        vm.startPrank(bob);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        vm.startPrank(carol);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that ValueQuorumNumeratorUpdated event was emitted
        expectEmit();
        emit ValueQuorumNumeratorUpdated(oldValueQuorumNumerator, newValueQuorumNumerator);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 updatedValueQuorumNumerator = governor.valueQuorumNumerator();
        assertEq(updatedValueQuorumNumerator, newValueQuorumNumerator, "Value quorum numerator has not changed");
    }
}
