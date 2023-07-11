// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOG } from "../../src/interfaces/ISPOG.sol";
import { IList } from "../../src/interfaces/periphery/IList.sol";

import { List } from "../../src/periphery/List.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_AppendAddressToList is SPOGBaseTest {

    address internal listToAddAddressTo;
    address internal addressToAdd;

    function setUp() public override {
        super.setUp();

        addNewListToSpog();
        listToAddAddressTo = address(list);
        addressToAdd = address(0x1234);
    }

    function test_Revert_AppendToListWhenNotCallingFromGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.append(listToAddAddressTo, addressToAdd);
    }

    function test_Revert_WhenListNotInMasterList() external {
        listToAddAddressTo = address(new List("New List"));

        bytes memory expectedError = abi.encodeWithSignature("ListIsNotInMasterList()");

        vm.expectRevert(expectedError);
        vm.prank(address(governor));
        ISPOG(spog).append(listToAddAddressTo, addressToAdd);
    }

    function test_SPOGProposalToAppendToAList() public {
        // create proposal to append address to list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", listToAddAddressTo, addressToAdd);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);

        // assert that vault has cash balance paid for proposals
        assertTrue(
            cash.balanceOf(address(vault)) == tax * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
        );

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
        assertTrue(IList(listToAddAddressTo).contains(addressToAdd), "Address was not added to list");
    }

}
