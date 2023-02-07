// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";

import "../src/SPOG.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {SPOGVote} from "src/tokens/SPOGVote.sol";
import {List} from "src/List.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOGTest is Test {
    SPOG public spog;
    SPOGVote public spogVote;
    SPOGDeployScript public deployScript;
    List public list;

    address public deployer = vm.addr(0x12345);
    address public user1 = vm.addr(0x6789);

    function setUp() public {
        deployScript = new SPOGDeployScript();
        deployScript.setUp();
        deployScript.run();

        spog = deployScript.spog();
        spogVote = SPOGVote(address(deployScript.vote()));
    }

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

    function testSPOGProposalToAddList() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("newList()");
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
    }
}
