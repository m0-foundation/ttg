// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "test/Base.t.sol";
import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";
import "src/SPOG.sol";
import {IGovSPOG} from "src/interfaces/IGovSPOG.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {SPOGVote} from "src/tokens/SPOGVote.sol";
import {SPOGValue} from "src/tokens/SPOGValue.sol";
import {IList} from "src/interfaces/IList.sol";
import {List} from "src/List.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOGTest is BaseTest {
    SPOG public spog;
    SPOGVote public spogVote;
    GovSPOG public govSPOGVote;
    SPOGValue public spogValue;
    GovSPOG public govSPOGValue;
    SPOGDeployScript public deployScript;
    List public list;

    enum VoteType {
        No,
        Yes
    }

    event DoubleQuorumInitiated(bytes32 indexed identifier);
    event DoubleQuorumFinalized(bytes32 indexed identifier);

    function setUp() public {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        spogVote = SPOGVote(address(deployScript.vote()));
        govSPOGVote = deployScript.govSPOGVote();
        spogValue = SPOGValue(address(deployScript.value()));
        govSPOGValue = deployScript.govSPOGValue();

        // mint spogVote to address(this) and self-delegate
        deal({token: address(spogVote), to: address(this), give: 100e18});
        spogVote.delegate(address(this));

        // mint spogValue to address(this) and self-delegate
        deal({token: address(spogValue), to: address(this), give: 100e18});
        spogValue.delegate(address(this));

        // deploy list and change admin to spog
        list = new List("My List");
        list.changeAdmin(address(spog));
    }

    /**********************************/
    /******** Helper functions ********/
    /**********************************/
    function getProposalIdAndHashedDescription(
        GovSPOG govSPOG,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) private pure returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = govSPOG.hashProposal(
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
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = "Add new list";

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

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpogAndAppendAnAddressToIt() private {
        addNewListToSpog();

        address listToAddAddressTo = address(list);
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

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);
    }

    /**********************************/
    /********* Start of Tests ********/
    /********************************/

    function test_SPOGHasSetInitialValuesCorrectly() public view {
        (
            uint256 tax,
            uint256 inflatorTime,
            uint256 sellTime,
            uint256 inflator,
            uint256 reward,
            IERC20 cash
        ) = spog.spogData();

        assert(address(cash) == address(deployScript.cash()));
        assert(inflator == deployScript.inflator());
        assert(reward == deployScript.reward());
        assert(govSPOGVote.votingPeriod() == deployScript.voteTime());
        assert(govSPOGValue.votingPeriod() == deployScript.forkTime());
        assert(inflatorTime == deployScript.inflatorTime());
        assert(sellTime == deployScript.sellTime());
        assert(govSPOGVote.quorumNumerator() == deployScript.voteQuorum());
        assert(govSPOGValue.quorumNumerator() == deployScript.valueQuorum());
        assert(tax == deployScript.tax());
        assert(
            address(govSPOGVote.votingToken()) == address(deployScript.vote())
        );
        assert(
            address(govSPOGValue.votingToken()) == address(deployScript.value())
        );
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assert(taxRangeMin == deployScript.taxRange(0));
        assert(taxRangeMax == deployScript.taxRange(1));
    }

    function test_RevertWhen_AddingNewList_NotCallingFromGovernance() external {
        vm.expectRevert("SPOG: Only GovSPOG");
        spog.addNewList(IList(address(list)));
    }

    function test_SPOGProposalToAddList() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = "Add new list";

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
        assert(
            deployScript.cash().balanceOf(address(spog)) == deployScript.tax()
        );

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // proposal should be active now
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Active,
            "Not in active state"
        );

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Succeeded,
            "Not in succeeded state"
        );

        // TODO: do we need to queue for a time lock execution?
        // queue proposal
        // spog.queue(proposalId);

        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Executed,
            "Proposal not executed"
        );

        // assert that list was created
        address createdList = address(list);

        assertTrue(
            spog.isListInMasterList(createdList),
            "List was not created"
        );
    }

    function testRevertRemoveListWhenNotCallingFromGovernance() public {
        addNewListToSpog();
        address listToRemove = address(list);

        vm.expectRevert("SPOG: Only GovSPOG");
        spog.removeList(IList(listToRemove));
    }

    function testSPOGProposalToRemoveList() public {
        addNewListToSpog();

        address listToRemove = address(list);

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
                deployScript.tax() * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
        );

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // proposal should be active now
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Active,
            "Not in active state"
        );

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Succeeded,
            "Not in succeeded state"
        );

        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(
            govSPOGVote.state(proposalId) == IGovernor.ProposalState.Executed,
            "Proposal not executed"
        );

        // assert that list was removed
        assertTrue(
            !spog.isListInMasterList(listToRemove),
            "List was not removed"
        );
    }

    function testRevertAppendToListWhenNotCallingFromGovernance() public {
        addNewListToSpog();
        address listToAddAddressTo = address(list);
        address addressToAdd = address(0x1234);

        vm.expectRevert("SPOG: Only GovSPOG");
        spog.append(addressToAdd, IList(listToAddAddressTo));
    }

    function testSPOGProposalToAppedToAList() public {
        addNewListToSpog();

        address listToAddAddressTo = address(list);
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
                deployScript.tax() * 2,
            "Balance of SPOG should be 2x tax, one from adding the list and one from the current proposal"
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
            IList(listToAddAddressTo).contains(addressToAdd),
            "Address was not added to list"
        );
    }

    function testRevertRemoveAddressFromListWhenNotCallingFromGovernance()
        public
    {
        addNewListToSpogAndAppendAnAddressToIt();

        address listToRemoveAddressFrom = address(list);
        address addressToRemove = address(0x1234);

        vm.expectRevert("SPOG: Only GovSPOG");
        spog.remove(addressToRemove, IList(listToRemoveAddressFrom));
    }

    function testSPOGProposalToRemoveAddressFromAList() public {
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
            "Balance of SPOG should be 3x tax, one from adding the list and one from the current proposal"
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

    function test_Revert_FileVarInSpogDataWhenNotCallingFromGovernance()
        public
    {
        bytes32 varName = "reward";
        bytes memory varValue = abi.encode(11);
        vm.expectRevert("SPOG: Only GovSPOG");
        spog.fileVarInSpogDataWithDoubleQuorum(varName, varValue);
    }

    function test_Revert_FileVarInSpogDataMustBeProposedByVoterHoldersFirst()
        public
    {
        bytes memory elevenAsCalldataValue = abi.encode(11);

        uint8 yesVote = 1;

        // value holders vote on proposal
        address[] memory targetsForValueHolders = new address[](1);
        targetsForValueHolders[0] = address(spog);
        uint256[] memory valuesForValueHolders = new uint256[](1);
        valuesForValueHolders[0] = 0;
        bytes[] memory calldatasForValueHolders = new bytes[](1);

        calldatasForValueHolders[0] = abi.encodeWithSignature(
            "fileVarInSpogDataWithDoubleQuorum(bytes32,bytes)",
            "reward",
            elevenAsCalldataValue
        );
        string
            memory descriptionForValueHolders = "GovSPOGValue change reward variable in spog";

        (
            bytes32 hashedDescriptionForValueHolders,
            uint256 proposalIdForValueHolders
        ) = getProposalIdAndHashedDescription(
                govSPOGValue,
                targetsForValueHolders,
                valuesForValueHolders,
                calldatasForValueHolders,
                descriptionForValueHolders
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            descriptionForValueHolders
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        vm.expectRevert("SPOG: Double quorum not met");
        govSPOGValue.execute(
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            hashedDescriptionForValueHolders
        );

        (, , , , uint256 rewardSecondCheck, ) = spog.spogData();
        // assert that reward was not modified
        assertTrue(
            rewardSecondCheck == deployScript.reward(),
            "Reward must not be changed"
        );
    }

    function test_FileVarInSpogData_SPOGProposalToChangeVariableInSpog()
        public
    {
        bytes memory elevenAsCalldataValue = abi.encode(11);
        uint8 yesVote = 1;

        // create proposal to change variable in spog
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "fileVarInSpogDataWithDoubleQuorum(bytes32,bytes)",
            "reward",
            elevenAsCalldataValue
        );
        string memory description = "Change reward variable in spog";

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

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // bytes32 reward = bytes32("reward");
        // bytes32 identifier = keccak256(
        //     abi.encodePacked(reward, elevenAsCalldataValue)
        // );
        // check that DoubleQuorumInitiated event was triggered
        // expectEmit();
        // emit DoubleQuorumInitiated(identifier);
        // execute proposal
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        (, , , , uint256 rewardFirstCheck, ) = spog.spogData();
        console.log("rewardFirstCheck", rewardFirstCheck);

        // assert that reward has not been changed yet as it needs to be voted on again by value holders
        assertFalse(
            rewardFirstCheck == 11,
            "Reward should not have been changed"
        );

        /**********  value holders vote on proposal **********/
        vm.warp(1 hours);

        (
            bytes32 hashedDescriptionForValueHolders,
            uint256 proposalIdForValueHolders
        ) = getProposalIdAndHashedDescription(
                govSPOGValue,
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        // // check that DoubleQuorumFinalized event was triggered
        // expectEmit();
        // emit DoubleQuorumFinalized("reward", elevenAsCalldataValue);
        govSPOGValue.execute(
            targets,
            values,
            calldatas,
            hashedDescriptionForValueHolders
        );

        (, , , , uint256 rewardSecondCheck, ) = spog.spogData();
        // assert that reward was modified by double quorum
        assertTrue(rewardSecondCheck == 11, "Reward was not changed");
    }
}
