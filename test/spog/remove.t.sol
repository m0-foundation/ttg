// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_RemoveAddressFromList is SPOG_Base {
    address internal listToRemoveAddressFrom;
    address internal addressToRemove;

    function setUp() public override {
        super.setUp();

        addNewListToSpogAndAppendAnAddressToIt();
        listToRemoveAddressFrom = address(list);
        addressToRemove = address(0x1234);
    }

    function test_Revert_RemoveAddressFromListWhenNotCallingFromGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.remove(listToRemoveAddressFrom, addressToRemove);
    }

    function test_Revert_WhenListNotInMasterList() external {
        bytes memory expectedError = abi.encodeWithSignature("ListIsNotInMasterList()");

        vm.expectRevert(expectedError);
        vm.prank(address(governor));
        spog.remove(address(0x1234), addressToRemove);
    }

    function test_SPOGProposalToRemoveAddressFromAList() public {
        // create proposal to remove address from list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("remove(address,address)", listToRemoveAddressFrom, addressToRemove);
        string memory description = "Remove address from a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);

        // assert that vault has cash balance paid for proposals
        assertTrue(
            cash.balanceOf(address(valueVault)) == tax * 3,
            "Balance of SPOG should be 3x tax, one from adding the list to the SPOG, one from append an address to the list,  and one from the current proposal"
        );

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        vm.prank(alice);
        governor.castVote(proposalId, yesVote);

        vm.prank(bob);
        governor.castVote(proposalId, yesVote);

        vm.prank(charlie);
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(!IList(listToRemoveAddressFrom).contains(addressToRemove), "Address was not removed from list");
    }
}
