// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOG_AddNewList is SPOG_Base {
    function test_Revert_WhenAddingNewList_NotCallingFromGovernance() external {
        vm.expectRevert("SPOG: Only vote governor");
        spog.addNewList(IList(address(list)));
    }

    function test_SPOGProposalToAddNewList() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = "Add new list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertEq(deployScript.cash().balanceOf(address(vault)), deployScript.tax());

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // proposal should be active now
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // check proposal is not yet succeeded
        assertFalse(voteGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Already in succeeded state");

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        voteGovernor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // TODO: do we need to queue for a time lock execution?
        // queue proposal
        // spog.queue(proposalId);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

        // assert that list was created
        address createdList = address(list);

        assertTrue(spog.isListInMasterList(createdList), "List was not created");
    }
}
