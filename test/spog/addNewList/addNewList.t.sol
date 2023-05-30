// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_AddNewList is SPOG_Base {
    function test_Revert_AddNewList_WhenCallerIsNotSPOG() external {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        ISPOG(spog).addNewList(address(list));
    }

    function test_Revert_AddNewList_WhenListAdminIsNotSPOG() external {
        // set list admin to different spog
        SPOG spog2 = deployScript.createSpog(true);
        vm.prank(address(spog));
        IList(list).changeAdmin(address(spog2));

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");

        vm.expectRevert(expectedError);
        vm.prank(address(governor));
        ISPOG(spog).addNewList(address(list));
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

        IERC20(deployScript.cash()).approve(address(spog), deployScript.tax());

        bytes memory expectedError = abi.encodeWithSignature("ListAdminIsNotSPOG()");
        vm.expectRevert(expectedError);
        IGovernor(governor).propose(targets, values, calldatas, description);
    }

    function test_AddNewList() public {
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
        IERC20(deployScript.cash()).approve(address(spog), deployScript.tax());
        IGovernor(governor).propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertEq(IERC20(deployScript.cash()).balanceOf(address(valueVault)), deployScript.tax());

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            IGovernor(governor).state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + IGovernor(governor).votingDelay() + 1);

        // proposal should be active now
        assertTrue(IGovernor(governor).state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // check proposal is not yet succeeded
        assertFalse(
            IGovernor(governor).state(proposalId) == IGovernor.ProposalState.Succeeded, "Already in succeeded state"
        );

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        IGovernor(governor).castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // check proposal is succeeded
        assertTrue(IGovernor(governor).state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // execute proposal
        IGovernor(governor).execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(IGovernor(governor).state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

        // assert that list was added to masterlist
        assertTrue(ISPOG(spog).isListInMasterList(list), "List was not created");
    }
}
