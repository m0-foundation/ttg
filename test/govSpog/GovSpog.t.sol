// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "test/Base.t.sol";

import "src/SPOG.sol";
import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";
import {GovSPOG} from "src/GovSPOG.sol";
import {SPOGVote} from "src/tokens/SPOGVote.sol";
import {IList} from "src/interfaces/IList.sol";
import {List} from "src/List.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract GovSPOGTest is BaseTest {
    SPOG public spog;
    SPOGVote public spogVote;
    GovSPOG public govSPOG;
    SPOGDeployScript public deployScript;
    List public list;

    function setUp() public {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        spogVote = SPOGVote(address(deployScript.vote()));
        govSPOG = deployScript.govSPOG();

        // mint spogVote to address(this) and self-delegate
        deal({token: address(spogVote), to: address(this), give: 100e18});
        spogVote.delegate(address(this));

        // deploy list and change admin to spog
        list = new List("My List");
        list.changeAdmin(address(spog));
    }

    function proposeAddingNewListToSpog() private returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = "Add new list";

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = govSPOG.hashProposal(
            targets,
            values,
            calldatas,
            hashedDescription
        );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        return proposalId;
    }

    function testStartOfNextVotingPeriod() public {
        uint256 votingPeriod = govSPOG.votingPeriod();
        uint256 startOfNextVotingPeriod = govSPOG.startOfNextVotingPeriod();

        assertTrue(startOfNextVotingPeriod > block.number);
        assertTrue(startOfNextVotingPeriod == block.number + votingPeriod);
    }

    function testCanOnlyVoteOnAProposalAfterItsVotingDelay() public {
        // propose adding a new list to spog
        uint256 proposalId = proposeAddingNewListToSpog();

        uint8 yesVote = 1;

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        govSPOG.castVote(proposalId, yesVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            govSPOG.state(proposalId) == IGovernor.ProposalState.Pending,
            "Proposal is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOG.votingDelay() + 1);

        // cast vote on proposal
        govSPOG.castVote(proposalId, yesVote);

        // check that proposal has 1 vote
        (uint256 noVotes, uint256 yesVotes) = govSPOG.proposalVotes(proposalId);

        console.log("noVotes: ", noVotes);
        console.log("yesVotes: ", yesVotes);

        // spogVote balance of voter
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        assertTrue(
            yesVotes == spogVoteBalance,
            "Proposal does not have expected yes vote"
        );
        assertTrue(noVotes == 0, "Proposal does not have 0 no vote");
    }
}
