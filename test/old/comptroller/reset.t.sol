// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import { IGovernor } from "../ImportedInterfaces.sol";

// import { IRegistrar } from "../../src/registrar/IRegistrar.sol";
// import { IDualGovernor } from "../../src/governor/IDualGovernor.sol";

// import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

// contract SPOG_reset is SPOGBaseTest {
//     event ResetExecuted(address indexed newGovernor, address indexed newVote, uint256 indexed snapshotId);

//     /******************************************************************************************************************/
//     /*** HELPERS                                                                                                    ***/
//     /******************************************************************************************************************/

//     function proposeGovernanceReset(
//         string memory proposalDescription
//     ) private returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32) {
//         address[] memory targets = new address[](1);
//         targets[0] = address(registrar);
//         uint256[] memory values = new uint256[](1);
//         values[0] = 0;
//         bytes[] memory calldatas = new bytes[](1);
//         bytes memory callData = abi.encodeWithSignature("reset()");
//         string memory description = proposalDescription;
//         calldatas[0] = callData;

//         bytes32 hashedDescription = keccak256(abi.encodePacked(description));
//         uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

//         // create proposal
//         cash.approve(address(registrar), 12 * deployScript.tax());

//         // Check the event is emitted
//         // TODO: check proposal
//         // expectEmit();
//         // emit NewValueQuorumProposal(proposalId);

//         uint256 spogProposalId = governor.propose(targets, values, calldatas, description);

//         // Make sure the proposal is immediately (+1 block) votable
//         assertEq(governor.proposalSnapshot(proposalId), block.number + 1);

//         assertTrue(spogProposalId == proposalId, "registrar proposal id does not match value governor proposal id");

//         return (proposalId, targets, values, calldatas, hashedDescription);
//     }

//     function executeValidProposal() private {
//         IDualGovernor governor = IDualGovernor(registrar.governor());
//         address[] memory targets = new address[](1);
//         targets[0] = address(registrar);
//         uint256[] memory values = new uint256[](1);
//         values[0] = 0;
//         bytes[] memory calldatas = new bytes[](1);
//         calldatas[0] = abi.encodeWithSignature("addToList(bytes32,address)", LIST_NAME, alice);
//         string memory description = "Add alice to list";

//         (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
//             targets,
//             values,
//             calldatas,
//             description
//         );

//         // vote on proposal
//         cash.approve(address(registrar), deployScript.tax());
//         governor.propose(targets, values, calldatas, description);

//         // fast forward to an active voting period
//         vm.roll(block.number + governor.votingDelay() + 1);

//         // cast vote on proposal
//         governor.castVote(proposalId, yesVote);
//         // fast forward to end of voting period
//         vm.roll(block.number + governor.votingPeriod() + 1);

//         // execute proposal
//         governor.execute(targets, values, calldatas, hashedDescription);
//     }

//     function test_Revert_Reset_WhenNotCalledByGovernance() public {
//         vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
//         registrar.reset();
//     }

//     function test_Reset_Success() public {
//         (
//             uint256 proposalId,
//             address[] memory targets,
//             uint256[] memory values,
//             bytes[] memory calldatas,
//             bytes32 hashedDescription
//         ) = proposeReset("Propose reset of vote governance");

//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

//         // fast forward to an active voting period
//         vm.roll(block.number + 2);
//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

//         // value holders vote on proposal
//         governor.castVote(proposalId, yesVote);

//         vm.prank(alice);
//         governor.castVote(proposalId, yesVote);

//         vm.prank(bob);
//         governor.castVote(proposalId, yesVote);

//         // proposal is now in succeeded state, it reached quorum
//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

//         address governorBeforeFork = registrar.governor();

//         vm.expectEmit(false, false, false, false);
//         address anyAddress = address(0);
//         emit ResetExecuted(anyAddress, anyAddress, 0);
//         governor.execute(targets, values, calldatas, hashedDescription);

//         assertFalse(registrar.governor() == governorBeforeFork, "Governor was not reset");

//         assertEq(
//             IDualGovernor(registrar.governor()).voteQuorumNumerator(),
//             65,
//             "Governor quorum was not set correctly"
//         );

//         assertEq(
//             IDualGovernor(registrar.governor()).votingPeriod(),
//             216_000,
//             "Governor voting delay was not set correctly"
//         );

//         updateAddresses();
//         initializeSelf();

//         // Make sure governance is functional
//         executeValidProposal();
//     }

//     function test_Reset_ValidateProposalState() public {
//         (uint256 proposalId, , , , ) = proposeReset("Propose reset of vote governance");

//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

//         // fast forward to an active voting period
//         vm.roll(block.number + 2);
//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

//         // value holders vote on proposal
//         governor.castVote(proposalId, yesVote);

//         vm.prank(alice);
//         governor.castVote(proposalId, yesVote);

//         vm.prank(bob);
//         governor.castVote(proposalId, yesVote);

//         // proposal is now in succeeded state, it reached quorum
//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

//         // fast forward to the end of active voting period
//         vm.roll(governor.startOf(governor.currentEpoch() + 1));

//         // proposal is now in succeeded state, it reached quorum
//         assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Expired, "Not in expired state");
//     }
// }
