// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/console.sol";
import {BaseTest} from "test/Base.t.sol";
import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";
import "src/core/SPOG.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {SPOGGovernor} from "src/core/SPOGGovernor.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {List} from "src/periphery/List.sol";
import {Vault} from "src/periphery/Vault.sol";

contract SPOG_Base is BaseTest {
    SPOG public spog;
    SPOGVotes public spogVote;
    SPOGGovernor public voteGovernor;
    SPOGVotes public spogValue;
    SPOGGovernor public valueGovernor;
    SPOGDeployScript public deployScript;
    List public list;
    Vault public vault;

    enum VoteType {
        No,
        Yes
    }

    function setUp() public virtual {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        spogVote = SPOGVotes(address(deployScript.vote()));
        voteGovernor = deployScript.voteGovernor();
        spogValue = SPOGVotes(address(deployScript.value()));
        valueGovernor = deployScript.valueGovernor();

        // mint spogVote to address(this) and self-delegate
        deal({token: address(spogVote), to: address(this), give: 100e18, adjust: true});
        spogVote.delegate(address(this));

        // mint spogValue to address(this) and self-delegate
        deal({token: address(spogValue), to: address(this), give: 100e18, adjust: true});
        spogValue.delegate(address(this));

        // deploy list and change admin to spog
        list = new List("My List");
        list.changeAdmin(address(spog));

        vault = deployScript.vault();
    }

    /* Helper functions */
    function getProposalIdAndHashedDescription(
        SPOGGovernor governor,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal pure returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpog() internal {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = "Add new list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(ISPOGGovernor(address(voteGovernor)), targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        voteGovernor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        voteGovernor.execute(targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpogAndAppendAnAddressToIt() internal {
        addNewListToSpog();

        address listToAddAddressTo = address(list);
        address addressToAdd = address(0x1234);

        // create proposal to remove list
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", addressToAdd, listToAddAddressTo);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(ISPOGGovernor(address(voteGovernor)), targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        voteGovernor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // execute proposal
        voteGovernor.execute(targets, values, calldatas, hashedDescription);
    }
}
