// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/console.sol";
import {BaseTest} from "test/Base.t.sol";
import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";
import "src/core/SPOG.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {SPOGGovernor} from "src/core/governor/SPOGGovernor.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {List} from "src/periphery/List.sol";
import {VoteVault} from "src/periphery/vaults/VoteVault.sol";
import {ValueVault} from "src/periphery/vaults/ValueVault.sol";

contract SPOG_Base is BaseTest {
    SPOG public spog;
    SPOGGovernor public governor;
    SPOGVotes public spogVote;
    SPOGVotes public spogValue;
    SPOGDeployScript public deployScript;
    List public list;
    VoteVault public voteVault;
    ValueVault public valueVault;
    IERC20 public cash;

    enum VoteType {
        No,
        Yes
    }

    function setUp() public virtual {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        governor = deployScript.governor();
        spogVote = SPOGVotes(address(deployScript.vote()));
        spogValue = SPOGVotes(address(deployScript.value()));

        // mint spogVote to address(this) and self-delegate
        spogVote.mint(address(this), 100e18);
        spogVote.delegate(address(this));

        // mint spogValue to address(this) and self-delegate
        spogValue.mint(address(this), 100e18);
        spogValue.delegate(address(this));

        // deploy list and change admin to spog
        list = new List("My List");
        list.changeAdmin(address(spog));

        voteVault = deployScript.voteVault();
        valueVault = deployScript.valueVault();

        cash = IERC20(address(deployScript.cash()));
    }

    /* Helper functions */
    function getProposalIdAndHashedDescription(
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
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpogAndAppendAnAddressToIt() internal {
        addNewListToSpog();

        address listToAddAddressTo = address(list);
        address addressToAdd = address(0x1234);

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

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }
}
