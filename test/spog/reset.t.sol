// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IGovernor } from "../interfaces/ImportedInterfaces.sol";

import { ISPOG } from "../../src/interfaces/ISPOG.sol";
import { ISPOGGovernor } from "../../src/interfaces/ISPOGGovernor.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_reset is SPOGBaseTest {
    event ResetExecuted(address indexed newGovernor, uint256 indexed snapshotId);

    /******************************************************************************************************************/
    /*** HELPERS                                                                                                    ***/
    /******************************************************************************************************************/

    function executeValidProposal() private {
        setUp();

        ISPOGGovernor governor = ISPOGGovernor(spog.governor());
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addToList(bytes32,address)", LIST_NAME, alice);
        string memory description = "Add alice to list";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        // vote on proposal
        cash.approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_Revert_Reset_WhenNotCalledByGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.reset(address(governor));
    }

    function test_Reset_Success() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeReset("Propose reset of vote governance", address(value));

        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + 2);
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // proposal is now in succeeded state, it reached quorum
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        address governorBeforeFork = spog.governor();

        vm.expectEmit(false, false, false, false);
        address anyAddress = address(0);
        emit ResetExecuted(anyAddress, 0);
        governor.execute(targets, values, calldatas, hashedDescription);

        assertFalse(spog.governor() == governorBeforeFork, "Governor was not reset");

        assertEq(ISPOGGovernor(spog.governor()).voteQuorumNumerator(), 5, "Governor quorum was not set correctly");

        assertEq(ISPOGGovernor(spog.governor()).votingPeriod(), 216_000, "Governor voting delay was not set correctly");

        // Make sure governance is functional
        executeValidProposal();
    }

    function test_Reset_ValidateProposalState() public {
        (uint256 proposalId, , , , ) = proposeReset("Propose reset of vote governance", address(value));

        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + 2);
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // proposal is now in succeeded state, it reached quorum
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingPeriod());

        // proposal is now in succeeded state, it reached quorum
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Expired, "Not in expired state");
    }
}
