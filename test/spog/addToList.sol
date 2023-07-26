// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "../../src/interfaces/ISPOG.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_AddToList is SPOGBaseTest {
    address internal addressToAdd;

    function setUp() public override {
        super.setUp();

        addressToAdd = address(0x1234);
    }

    function test_Revert_AddToListWhenNotCallingFromGovernance() public {
        vm.expectRevert(ISPOG.CallerIsNotGovernor.selector);
        spog.addToList(LIST_NAME, addressToAdd);
    }

    function test_SPOGProposalToAddToAList() public {
        // create proposal to add address to list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addToList(bytes32,address)", LIST_NAME, addressToAdd);
        string memory description = "Add address to a list";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);

        // assert that vault has cash balance paid for proposals
        assertTrue(cash.balanceOf(address(vault)) == tax, "Balance of SPOG should be 1x tax from the current proposal");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;

        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(spog.listContains(LIST_NAME, addressToAdd), "Address was not added to list");
    }
}
