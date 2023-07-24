// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IGovernor } from "../interfaces/ImportedInterfaces.sol";

import { ISPOG } from "../../src/interfaces/ISPOG.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_emergency is SPOGBaseTest {
    // Setup function, add test-specific initializations here
    address internal addressToChange;

    function setUp() public override {
        super.setUp();

        // Initial state - list contains 1 participant
        (, addressToChange) = addAnAddressToList();
    }

    /******************************************************************************************************************/
    /*** HELPERS                                                                                                    ***/
    /******************************************************************************************************************/

    function proposeEmergencyRemoveFromList()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        // assert that address is in the list
        assertTrue(spog.listContains(LIST_NAME, addressToChange), "Address is not in the list");

        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(LIST_NAME, addressToChange);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.RemoveFromList),
            callData
        );

        string memory description = "Emergency remove of merchant";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        cash.approve(address(spog), tax);

        //TODO: Check that `NewEmergencyProposal` event is emitted
        // expectEmit();
        // emit NewEmergencyProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function proposeEmergencyAddToList()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        vm.prank(address(spog));
        // assert that address is not in the list
        assertFalse(spog.listContains(LIST_NAME, alice), "Address is in the list");

        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(LIST_NAME, alice);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.AddToList),
            callData
        );

        string memory description = "Emergency add of merchant";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );
        cash.approve(address(spog), tax);

        // TODO: Check that `NewEmergencyProposal` event is emitted
        // expectEmit();
        // emit NewEmergencyProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function proposeEmergencyUpdateConfig()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(bytes32("someConfigName"), bytes32("someValue"));

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.UpdateConfig),
            callData
        );

        string memory description = "Emergency update config";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        // emergency propose, tax price
        cash.approve(address(spog), tax);

        //TODO: Check that `NewEmergencyProposal` event is emitted
        // expectEmit();
        // emit NewEmergencyProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function test_Emergency_RemoveFromList() public {
        // create proposal to emergency remove address from list
        uint256 balanceBeforeProposal = cash.balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeEmergencyRemoveFromList();

        // Check that tax was paid
        uint256 balanceAfterProposal = cash.balanceOf(address(vault));
        assertEq(balanceAfterProposal - balanceBeforeProposal, tax, "Emergency proposal costs 1 * tax");

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        assertEq(governor.proposalSnapshot(proposalId), block.number + 1);

        // check proposal is pending
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + 2);

        // check proposal is active
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is not in the list
        assertFalse(spog.listContains(LIST_NAME, addressToChange), "Address is still in the list");
    }

    function test_Emergency_AppendToList() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeEmergencyAddToList();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertTrue(spog.listContains(LIST_NAME, addressToChange), "Address is not in the list");
    }

    function test_Emergency_UpdateConfig() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeEmergencyUpdateConfig();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that config was changed
        assertEq(spog.get("someConfigName"), "someValue", "Config did not match");
    }

    function test_Revert_Emergency_WhenNotEnoughTaxPaid() public {
        bytes memory callData = abi.encode(LIST_NAME, addressToChange);

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.RemoveFromList),
            callData
        );

        string memory description = "Emergency remove of merchant";

        // emergency propose, 1 * tax price is needed, but only 0.5 * tax is approved to be paid
        cash.approve(address(spog), tax / 2);
        vm.expectRevert("ERC20: insufficient allowance");
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Emergency_WhenQuorumWasNotReached() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeEmergencyRemoveFromList();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, noVote);

        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal is active
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was defeated
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Defeated, "Not in defeated state");

        // assert that address is in the list
        assertTrue(spog.listContains(LIST_NAME, addressToChange), "Address is not in the list");
    }

    function test_Revert_Emergency_WhenProposalIsExpired() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeEmergencyRemoveFromList();

        // check proposal is pending
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward by a few blocks
        vm.roll(block.number + 2);

        // check proposal is active
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod());

        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Expired, "Not in `Expired` state");

        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);
    }
}
