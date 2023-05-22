// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOG_emergencyRemove is SPOG_Base {
    address internal addressToRemove;
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

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function createEmergencyProposal()
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        // assert that address is in the list
        assertTrue(list.contains(addressToRemove), "Address is not in the list");

        // the actual proposal to wrap as an emergency
        bytes4 selector = spog.remove.selector;
        bytes memory callData = abi.encode(addressToRemove, address(list));

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergency(bytes4,bytes)", selector, callData);
        string memory description = "Emergency remove of merchant";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // emergency propose, 12 * tax price
        deployScript.cash().approve(address(spog), spog.EMERGENCY_TAX_MULTIPLIER() * deployScript.tax());

        // Check that `NewEmergencyProposal` event is emitted
        expectEmit();
        emit NewEmergencyProposal(proposalId);
        spog.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function test_Revert_EmergencyRemove_WhenNotEnoughTaxPaid() public {
        bytes4 selector = spog.remove.selector;
        bytes memory callData = abi.encode(addressToRemove, address(list));

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("emergency(bytes4,bytes)", selector, callData);
        string memory description = "Emergency remove of merchant";

        // emergency propose, 12 * tax price is needed, but only 1 * tax is approved to be paid
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
        vm.roll(block.number + deployScript.time() + 1);

        vm.expectRevert("Governor: proposal not successful");
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal was defeated
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Defeated, "Not in defeated state");

        // assert that address is in the list
        assertTrue(list.contains(addressToRemove), "Address is not in the list");
    }

    function test_EmergencyRemove_BeforeDeadlineEnd() public {
        // create proposal to emergency remove address from list
        uint256 votingPeriodBeforeER = voteGovernor.votingPeriod();
        uint256 balanceBeforeProposal = deployScript.cash().balanceOf(address(valueVault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = createEmergencyProposal();

        // Check that tax was paid
        uint256 balanceAfterProposal = deployScript.cash().balanceOf(address(valueVault));
        assertEq(
            balanceAfterProposal - balanceBeforeProposal,
            spog.EMERGENCY_TAX_MULTIPLIER() * deployScript.tax(),
            "Emergency proposal costs 12x tax"
        );

        // Emergency proposal is in the governor list
        assertTrue(voteGovernor.emergencyProposals(proposalId), "Proposal was added to the list");

        assertEq(voteGovernor.proposalSnapshot(proposalId), block.number + 1);

        // check proposal is pending
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + 2);

        assertTrue(voteGovernor.votingPeriod() == votingPeriodBeforeER, "Governor voting period was messed up");

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
        vm.roll(block.number + deployScript.time() + 1);

        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal was executed
        assertTrue(voteGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Not in executed state");

        // assert that address is in the list
        assertFalse(list.contains(addressToRemove), "Address is still in the list");
    }

    function test_EmergencyRemove_VoteAndValueTokensAreNotInflated() public {
        uint256 voteTokenInitialBalanceForVault = spogVote.balanceOf(address(voteVault));
        uint256 valueTokenInitialBalanceForVault = spogValue.balanceOf(address(voteVault));
        uint256 voteTotalBalance = spogVote.totalSupply();
        uint256 valueTotalBalance = spogValue.totalSupply();

        createEmergencyProposal();

        uint256 voteTokenBalanceAfterProposal = spogVote.balanceOf(address(voteVault));
        uint256 valueTokenBalanceAfterProposal = spogValue.balanceOf(address(voteVault));
        uint256 voteTotalBalanceAfterProposal = spogVote.totalSupply();
        uint256 valueTotalBalanceAfterProposal = spogValue.totalSupply();
        assertEq(
            voteTokenInitialBalanceForVault,
            voteTokenBalanceAfterProposal,
            "vault should have the same balance of vote tokens after emergency remove proposal"
        );
        assertEq(
            valueTokenInitialBalanceForVault,
            valueTokenBalanceAfterProposal,
            "vault should have the same balance of value tokens after emergency remove proposal"
        );
        assertEq(
            voteTotalBalance,
            voteTotalBalanceAfterProposal,
            "total supply of vote tokens should not change after emergency remove proposal"
        );
        assertEq(
            valueTotalBalance,
            valueTotalBalanceAfterProposal,
            "total supply of value tokens should not change after emergency remove proposal"
        );
    }
}
