// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import { IRegistrar } from "../../src/registrar/IRegistrar.sol";

// import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

// contract SPOG_RemoveFromList is SPOGBaseTest {
//     address internal addressToRemove;

//     function test_Revert_RemoveFromListWhenNotCallingFromGovernance() public {
//         vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
//         registrar.removeFromList(LIST_NAME, addressToRemove);
//     }

//     function test_SPOGProposalToRemoveFromAList() public {
//         (, addressToRemove) = addAnAddressToList();

//         // create proposal to remove address from list
//         address[] memory targets = new address[](1);
//         targets[0] = address(registrar);
//         uint256[] memory values = new uint256[](1);
//         values[0] = 0;
//         bytes[] memory calldatas = new bytes[](1);
//         calldatas[0] = abi.encodeWithSignature("removeFromList(bytes32,address)", LIST_NAME, addressToRemove);
//         string memory description = "Remove address from a list";

//         (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
//             targets,
//             values,
//             calldatas,
//             description
//         );

//         // vote on proposal
//         cash.approve(address(registrar), tax);
//         governor.propose(targets, values, calldatas, description);

//         // assert that vault has cash balance paid for proposals
//         assertTrue(
//             cash.balanceOf(address(vault)) == tax * 2,
//             "Balance of vault should be 3x tax, one from add an address to the list and one from the current proposal"
//         );

//         // fast forward to an active voting period
//         vm.roll(block.number + governor.votingDelay() + 1);

//         // cast vote on proposal
//         uint8 yesVote = 1;
//         governor.castVote(proposalId, yesVote);
//         // fast forward to end of voting period
//         vm.roll(block.number + governor.votingPeriod() + 1);

//         // execute proposal
//         governor.execute(targets, values, calldatas, hashedDescription);

//         // assert that address was added to list
//         assertFalse(registrar.listContains(LIST_NAME, addressToRemove), "Address was not removed from list");
//     }
// }
