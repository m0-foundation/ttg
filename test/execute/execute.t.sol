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

    function test_SPOGExecute() public {
        // Start at beginning of an epoch
        vm.roll(block.number + voteGovernor.startOfNextEpoch());

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // create proposal to append address to list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", addressToAdd, listToAddAddressTo);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // create proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        console.log("Created proposal", proposalId);
        console.log(" Block number", block.number);
        console.log(" Voting delay", voteGovernor.votingDelay());

        // fast forward to next voting period
        vm.roll(voteGovernor.startOfNextEpoch() + 1);

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // cast vote on proposal
        uint8 yesVote = 1;
        voteGovernor.castVote(proposalId, yesVote);

        console.log("Casted vote", proposalId);

        // fast forward to end of voting period
        vm.roll(voteGovernor.startOfNextEpoch() + 1);

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(IList(listToAddAddressTo).contains(addressToAdd), "Address was not added to list");
    }

    function test_Revert_SPOGExecute_onExpiration() public {
        // Start at beginning of an epoch
        vm.roll(block.number + voteGovernor.startOfNextEpoch());

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // create proposal to append address to list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", addressToAdd, listToAddAddressTo);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // create proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        console.log("Created proposal", proposalId);
        console.log(" Block number", block.number);
        console.log(" Voting delay", voteGovernor.votingDelay());

        // fast forward to next voting period
        vm.roll(voteGovernor.startOfNextEpoch() + 1);

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // cast vote on proposal
        uint8 yesVote = 1;
        voteGovernor.castVote(proposalId, yesVote);

        console.log("Casted vote", proposalId);

        // fast forward to next voting period
        vm.roll(voteGovernor.startOfNextEpoch() + 1);

        // do not execute

        // fast forward to next voting period
        vm.roll(voteGovernor.startOfNextEpoch() + 1);

        console.log("Block number", block.number);
        console.log(" Current epoch", voteGovernor.currentEpoch());

        // execute proposal
        vm.expectRevert("Governor: proposal not successful");
        spog.execute(targets, values, calldatas, hashedDescription);
    }
}
