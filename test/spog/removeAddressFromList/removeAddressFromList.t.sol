// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_RemoveAddressFromList is SPOG_Base {
    function test_Revert_RemoveAddressFromListWhenNotCallingFromGovernance()
        public
    {
        addNewListToSpogAndAppendAnAddressToIt();

        address listToRemoveAddressFrom = address(list);
        address addressToRemove = address(0x1234);

        vm.expectRevert("SPOG: Only GovSPOG");
        spog.remove(addressToRemove, IList(listToRemoveAddressFrom));
    }

    function test_SPOGProposalToRemoveAddressFromAList() public {
        addNewListToSpogAndAppendAnAddressToIt();

        address listToRemoveAddressFrom = address(list);
        address addressToRemove = address(0x1234);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "remove(address,address)",
            addressToRemove,
            listToRemoveAddressFrom
        );
        string memory description = "Remove address from a list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                govSPOGVote,
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGVote)),
            targets,
            values,
            calldatas,
            description
        );

        // assert that spog has cash balance
        assertTrue(
            deployScript.cash().balanceOf(address(spog)) ==
                deployScript.tax() * 3,
            "Balance of SPOG should be 3x tax, one from adding the list to the SPOG, one from append an address to the list,  and one from the current proposal"
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(
            !IList(listToRemoveAddressFrom).contains(addressToRemove),
            "Address was not removed from list"
        );
    }
}
