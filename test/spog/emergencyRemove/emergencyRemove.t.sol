// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOG_emergencyRemove is SPOG_Base {
    address internal addressToRemove;
    address internal addressToRemoveB;
    uint8 internal yesVote;
    uint8 internal noVote;

    event NewEmergencyProposal(uint256 indexed proposalId);

    function setUp() public override {
        super.setUp();

        noVote = 0;
        yesVote = 1;

        // Initial state - list contains 1 merchant
        addNewListToSpogAndAppendAnAddressToIt();
        addressToRemove = address(0x1234);
    }

    function createEmergencyProposal()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        // assert that address is in the list
        assertTrue(list.contains(addressToRemove), "Address is not in the list");

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergencyRemove(address,address)", addressToRemove, address(list));
        string memory description = "Emergency remove of merchant";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // emergency propose, 12 * tax price
        deployScript.cash().approve(address(spog), spog.EMERGENCY_REMOVE_TAX_MULTIPLIER() * deployScript.tax());

        // Check that event is emitted
        expectEmit();
        emit NewEmergencyProposal(proposalId);
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function test_Revert_EmergencyRemove_WhenNotEnoughTaxPaid() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergencyRemove(address,address)", addressToRemove, address(list));
        string memory description = "Emergency remove of merchant";

        // emergency propose, 12 * tax price is needed, but 1 * tax is allowed to be paid
        deployScript.cash().approve(address(spog), deployScript.tax());
        vm.expectRevert("ERC20: insufficient allowance");
        spog.propose(targets, values, calldatas, description);
    }

    function test_Revert_EmergencyRemove_WhenQuorumWasNotReached() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyProposal();

        // Emergency proposal is in the governor list
        assertTrue(voteGovernor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, noVote);

        vm.expectRevert("Governor: proposal not successful");
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is active
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        vm.expectRevert("Governor: proposal not successful");
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal was defeated
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Defeated, "Not in defeated state");

        // assert that address is in the list
        assertTrue(list.contains(addressToRemove), "Address is not in the list");
    }

    function test_EmergencyRemove_BeforeDeadlineEnd() public {
        // create proposal to emergency remove address from list
        uint256 balanceBeforeProposal = deployScript.cash().balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyProposal();

        // Check that tax was paid
        uint256 balanceAfterProposal = deployScript.cash().balanceOf(address(vault));
        assertEq(
            balanceAfterProposal - balanceBeforeProposal,
            spog.EMERGENCY_REMOVE_TAX_MULTIPLIER() * deployScript.tax(),
            "Emergency proposal costs 12x tax"
        );

        // Emergency proposal is in the governor list
        assertTrue(voteGovernor.emergencyProposals(proposalId), "Proposal was added to the list");

        // check proposal is pending
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // check proposal is active
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // check proposal is succeeded
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertFalse(list.contains(addressToRemove), "Address is still in the list");
    }

    function test_EmergencyRemove_AfterDeadlineEnd() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyProposal();

        // Emergency proposal is in the governor list
        assertTrue(voteGovernor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertFalse(list.contains(addressToRemove), "Address is still in the list");
    }
}
