// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {List} from "src/periphery/List.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

contract SPOG_AddNewList is SPOG_Base {
    function test_Revert_WhenAddingNewList_NotCallingFromGovernance() external {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.addNewList(IList(address(list)));
    }

    function test_Revert_WhenListAdminIsNotSPOG() external {
        // set list admin to different spog
        SPOG spog2 = deployScript.createSpog(true);
        vm.prank(address(spog));
        list.changeAdmin(address(spog2));

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");

        vm.expectRevert(expectedError);
        vm.prank(address(governor));
        spog.addNewList(IList(address(list)));
    }

    function test_Revert_DuringProposal_WhenListAdminIsNotSPOG() public {
        address user = createUser("someUser");
        vm.prank(user);
        List newList = new List("Blah");

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", newList);
        string memory description = "Add new list";

        deployScript.cash().approve(address(spog), deployScript.tax());

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");

        vm.expectRevert(expectedError);
        governor.propose(targets, values, calldatas, description);
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
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertEq(deployScript.cash().balanceOf(address(valueVault)), deployScript.tax());

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // proposal should be active now
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // check proposal is not yet succeeded
        assertFalse(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Already in succeeded state");

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // TODO: do we need to queue for a time lock execution?
        // queue proposal
        // spog.queue(proposalId);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

        // assert that list was created
        address createdList = address(list);

        assertTrue(spog.isListInMasterList(createdList), "List was not created");
    }
}
