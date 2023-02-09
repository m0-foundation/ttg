// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";

import "../src/SPOG.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {SPOGVote} from "src/tokens/SPOGVote.sol";
import {IList} from "src/interfaces/IList.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOGTest is Test {
    SPOG public spog;
    SPOGVote public spogVote;
    SPOGDeployScript public deployScript;

    function setUp() public {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        spogVote = SPOGVote(address(deployScript.vote()));
    }

    /**********************************/
    /******** Helper functions ********/
    /**********************************/
    function getProposalIdAndHashedDescription(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) private view returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = spog.hashProposal(
            targets,
            values,
            calldatas,
            hashedDescription
        );
    }

    function addNewListToSpog() private {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList()");
        string memory description = "Add new list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpogAndAppendAnAddressToIt() private {
        addNewListToSpog();

        address listToAddAddressTo = spog.lists(0);
        address addressToAdd = address(0x1234);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "append(address,address)",
            addressToAdd,
            listToAddAddressTo
        );
        string memory description = "Append address to a list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);
    }

    /**********************************/
    /********* Start of Tests ********/
    /********************************/

    function testSPOGHasSetInitialValuesCorrectly() public view {
        (
            uint256 tax,
            uint256 currentEpoch,
            uint256 currentEpochEnd,
            uint256 valueQuorum,
            uint256 inflatorTime,
            uint256 sellTime,
            uint256 forkTime,
            uint256 inflator,
            uint256 reward,
            IERC20 cash
        ) = spog.spogData();

        assert(address(cash) == address(deployScript.cash()));
        assert(inflator == deployScript.inflator());
        assert(reward == deployScript.reward());
        assert(GovSPOG(spog).voteTime() == deployScript.voteTime());
        assert(inflatorTime == deployScript.inflatorTime());
        assert(sellTime == deployScript.sellTime());
        assert(forkTime == deployScript.forkTime());
        assert(GovSPOG(spog).quorumNumerator() == deployScript.voteQuorum());
        assert(valueQuorum == deployScript.valueQuorum());
        assert(tax == deployScript.tax());
        assert(currentEpoch == 1); // starts with epoch 1
        assert(
            address(GovSPOG(spog).spogVote()) == address(deployScript.vote())
        );
        assert(currentEpochEnd == block.number + deployScript.voteTime());
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assert(taxRangeMin == deployScript.taxRange(0));
        assert(taxRangeMax == deployScript.taxRange(1));
    }

    function testRevertAddNewListWhenNotCallingFromGovernance() public {
        vm.expectRevert("Governor: onlyGovernance");
        spog.addNewList();
    }

    function testSPOGProposalToAddList() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList()");
        string memory description = "Add new list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assert(
            deployScript.cash().balanceOf(address(spog)) == deployScript.tax()
        );

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // proposal should be active now
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Active,
            "Not in active state"
        );

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Succeeded,
            "Not in succeeded state"
        );

        // TODO: do we need to queue for a time lock execution?
        // queue proposal
        // spog.queue(proposalId);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Executed,
            "Proposal not executed"
        );

        // assert that list was created
        console.log("first list", spog.lists(0));
        address createdList = spog.lists(0);

        assertTrue(spog.masterlist(createdList), "List was not created");
    }

    function testRevertRemoveListWhenNotCallingFromGovernance() public {
        addNewListToSpog();
        address listToRemove = spog.lists(0);

        vm.expectRevert("Governor: onlyGovernance");
        spog.removeList(listToRemove);
    }

    function testSPOGProposalToRemoveList() public {
        addNewListToSpog();

        address listToRemove = spog.lists(0);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "removeList(address)",
            listToRemove
        );
        string memory description = "remove list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertTrue(
            deployScript.cash().balanceOf(address(spog)) ==
                deployScript.tax() * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
        );

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // proposal should be active now
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Active,
            "Not in active state"
        );

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Succeeded,
            "Not in succeeded state"
        );

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(
            spog.state(proposalId) == IGovernor.ProposalState.Executed,
            "Proposal not executed"
        );

        // assert that list was removed
        assertTrue(!spog.masterlist(listToRemove), "List was not removed");
    }

    function testRevertAppendToListWhenNotCallingFromGovernance() public {
        addNewListToSpog();
        address listToAddAddressTo = spog.lists(0);
        address addressToAdd = address(0x1234);

        vm.expectRevert("Governor: onlyGovernance");
        spog.append(addressToAdd, IList(listToAddAddressTo));
    }

    function testSPOGProposalToAppedToAList() public {
        addNewListToSpog();

        address listToAddAddressTo = spog.lists(0);
        address addressToAdd = address(0x1234);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "append(address,address)",
            addressToAdd,
            listToAddAddressTo
        );
        string memory description = "Append address to a list";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertTrue(
            deployScript.cash().balanceOf(address(spog)) ==
                deployScript.tax() * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
        );

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(
            IList(listToAddAddressTo).contains(addressToAdd),
            "Address was not added to list"
        );
    }

    function testRevertRemoveAddressFromListWhenNotCallingFromGovernance()
        public
    {
        addNewListToSpogAndAppendAnAddressToIt();

        address listToRemoveAddressFrom = spog.lists(0);
        address addressToRemove = address(0x1234);

        vm.expectRevert("Governor: onlyGovernance");
        spog.remove(addressToRemove, IList(listToRemoveAddressFrom));
    }

    function testSPOGProposalToRemoveAddressFromAList() public {
        addNewListToSpogAndAppendAnAddressToIt();

        address listToRemoveAddressFrom = spog.lists(0);
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
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // assert that spog has cash balance
        assertTrue(
            deployScript.cash().balanceOf(address(spog)) ==
                deployScript.tax() * 3,
            "Balance of SPOG should be 3x tax, one from adding the list and one from the current proposal"
        );

        // fast forward to an active voting period
        vm.roll(block.number + spog.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        spog.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // assert that address was added to list
        assertTrue(
            !IList(listToRemoveAddressFrom).contains(addressToRemove),
            "Address was not removed from list"
        );
    }
}
