// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_AppendAddressToList is SPOG_Base {
    address internal listToAddAddressTo;
    address internal addressToAdd;

    function setUp() public override {
        super.setUp();

        addNewListToSpog();
        listToAddAddressTo = address(list);
        addressToAdd = address(0x1234);
    }

    function test_Revert_SPOGExecute_onExpiration() public {
        // create proposal to append address to list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", addressToAdd, listToAddAddressTo);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // create proposal
        cash.approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // fast forward to next voting period
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to next voting period
        vm.roll(governor.startOf(governor.currentEpoch() + 1) + 1);

        // do not execute

        // fast forward to next voting period
        // Note: No extra +1 here.
        vm.roll(governor.startOf(governor.currentEpoch() + 1));
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Expired, "Proposal is not in an expired state");

        // execute proposal
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);
    }
}
