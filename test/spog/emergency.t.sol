// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "../../src/interfaces/ISPOG.sol";

import { IGovernor } from "../interfaces/ImportedInterfaces.sol";

import { ERC165 } from "../ImportedContracts.sol";
import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

interface IMockConfig {
    function someValue() external view returns (uint256);
}

contract MockConfig is IMockConfig, ERC165 {
    uint256 public immutable someValue = 1;

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IMockConfig).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract SPOG_emergency is SPOGBaseTest {
    address internal addressToChange;

    event NewEmergencyProposal(uint256 indexed proposalId);

    function setUp() public override {
        super.setUp();

        // Initial state - list contains 1 participant
        addNewListToSpogAndAppendAnAddressToIt();
        addressToChange = address(0x1234);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function createEmergencyRemoveProposal()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        // assert that address is in the list
        assertTrue(list.contains(addressToChange), "Address is not in the list");

        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(address(list), addressToChange);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("emergency(uint8,bytes)", uint8(ISPOG.EmergencyType.Remove), callData);

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

    function createEmergencyAppendProposal()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        vm.prank(address(spog));
        list.remove(addressToChange);
        // assert that address is not in the list
        assertFalse(list.contains(addressToChange), "Address is in the list");

        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(address(list), addressToChange);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("emergency(uint8,bytes)", uint8(ISPOG.EmergencyType.Append), callData);

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

    function createEmergencyConfigChangeProposal()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32, address)
    {
        MockConfig mockConfig = new MockConfig();

        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(keccak256("Fake Name"), address(mockConfig), type(IMockConfig).interfaceId);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.ChangeConfig),
            callData
        );

        string memory description = "Emergency change config";

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

        return (proposalId, targets, values, calldatas, hashedDescription, address(mockConfig));
    }

    function test_Revert_Emergency_WhenNotEnoughTaxPaid() public {
        bytes memory callData = abi.encode(addressToChange, address(list));

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergency(uint8,bytes)", uint8(ISPOG.EmergencyType.Remove), callData);
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
        ) = createEmergencyRemoveProposal();

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
        assertTrue(list.contains(addressToChange), "Address is not in the list");
    }

    function test_EmergencyRemove_BeforeDeadlineEnd() public {
        // create proposal to emergency remove address from list
        uint256 votingPeriodBeforeER = governor.votingPeriod();
        uint256 balanceBeforeProposal = cash.balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyRemoveProposal();

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

        assertTrue(governor.votingPeriod() == votingPeriodBeforeER, "Governor voting period was messed up");

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
        assertFalse(list.contains(addressToChange), "Address is still in the list");
    }

    function test_EmergencyRemove_AfterDeadlineEnd() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyRemoveProposal();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is not in the list
        assertFalse(list.contains(addressToChange), "Address is still in the list");
    }

    function test_EmergencyAppend_BeforeDeadlineEnd() public {
        // create proposal to emergency remove address from list
        uint256 votingPeriodBeforeER = governor.votingPeriod();
        uint256 balanceBeforeProposal = cash.balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyAppendProposal();

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

        assertTrue(governor.votingPeriod() == votingPeriodBeforeER, "Governor voting period was messed up");

        // check proposal is active
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertTrue(list.contains(addressToChange), "Address is not in the list");
    }

    function test_EmergencyAppend_AfterDeadlineEnd() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyAppendProposal();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertTrue(list.contains(addressToChange), "Address is not in the list");
    }

    function test_EmergencyChangeConfig_BeforeDeadlineEnd() public {
        // create proposal to emergency remove address from list
        uint256 votingPeriodBeforeER = governor.votingPeriod();
        uint256 balanceBeforeProposal = cash.balanceOf(address(vault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription,
            address configAddress
        ) = createEmergencyConfigChangeProposal();

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

        assertTrue(governor.votingPeriod() == votingPeriodBeforeER, "Governor voting period was messed up");

        // check proposal is active
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check proposal is succeeded
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that config was changed
        (address a, ) = spog.getConfig(keccak256("Fake Name"));
        assertEq(a, configAddress, "Config address did not match");
    }

    function test_EmergencyChangeConfig_AfterDeadlineEnd() public {
        // create proposal to emergency remove address from list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription,
            address configAddress
        ) = createEmergencyConfigChangeProposal();

        // Emergency proposal is in the governor list
        assertTrue(governor.emergencyProposals(proposalId), "Proposal was added to the list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that config was changed
        (address a, ) = spog.getConfig(keccak256("Fake Name"));
        assertEq(a, configAddress, "Config address did not match");
    }
}
