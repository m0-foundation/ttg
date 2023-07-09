// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/base/SPOG_Base.t.sol";

contract SPOG_AddNewList is SPOG_Base {
    // Events to test
    event ListAdded(address indexed list, string name);

    function test_Revert_AddNewList_WhenCallerIsNotSPOG() external {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.addList(address(list));
    }

    function test_Revert_AddNewList_WhenListAdminIsNotSPOG() external {
        // set list admin to different spog
        SPOG spog2 = deployScript.createSpog(true);
        vm.prank(address(spog));
        list.changeAdmin(address(spog2));

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");

        vm.expectRevert(expectedError);
        vm.prank(address(governor));
        spog.addList(address(list));
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
        calldatas[0] = abi.encodeWithSignature("addList(address)", newList);
        string memory description = "Add new list";

        cash.approve(address(spog), tax);

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");
        vm.expectRevert(expectedError);
        governor.propose(targets, values, calldatas, description);
    }

    function test_AddNewList() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addList(address)", address(list));
        string memory description = "Add new list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertEq(cash.balanceOf(address(vault)), tax);

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
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        expectEmit();
        emit ListAdded(address(list), list.name());

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

        // assert that list was added to masterlist
        assertTrue(spog.isListInMasterList(address(list)), "List was not created");
    }
}
