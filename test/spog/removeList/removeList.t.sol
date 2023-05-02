// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOG_RemoveList is SPOG_Base {
    function test_Revert_RemoveListWhenNotCallingFromGovernance() public {
        addNewListToSpog();
        address listToRemove = address(list);

        vm.expectRevert("SPOG: Only vote governor");
        spog.removeList(IList(listToRemove));
    }

    function test_Revert_WhenListNotInMasterList() external {
        address listToRemove = address(list);

        bytes memory expectedError = abi.encodeWithSignature("ListIsNotInMasterList()");

        vm.expectRevert(expectedError);
        vm.prank(address(voteGovernor));
        spog.removeList(IList(listToRemove));
    }

    function test_SPOGProposalToRemoveList() public {
        addNewListToSpog();

        address listToRemove = address(list);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("removeList(address)", listToRemove);
        string memory description = "remove list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that vault has cash balance paid for proposals
        assertTrue(
            deployScript.cash().balanceOf(address(vault)) == deployScript.tax() * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
        );

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // proposal should be active now
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        voteGovernor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // check proposal is succeeded
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

        // assert that list was removed
        assertTrue(!spog.isListInMasterList(listToRemove), "List was not removed");
    }
}
