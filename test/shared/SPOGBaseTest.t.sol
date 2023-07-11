// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IList } from "../../src/interfaces/periphery/IList.sol";
import { ISPOG, ISPOGGovernor, ISPOGVault } from "../../src/interfaces/ISPOG.sol";
import { IVOTE, IVALUE } from "../../src/interfaces/ITokens.sol";

import { List } from "../../src/periphery/List.sol";

import { SPOGDeployScript } from "../../script/SPOGDeploy.s.sol";

import { IERC20 } from "../interfaces/ImportedInterfaces.sol";

import { BaseTest } from "./BaseTest.t.sol";

contract SPOGBaseTest is BaseTest {

    SPOGDeployScript public deployScript;

    ISPOG public spog;
    ISPOGGovernor public governor;
    IVOTE public vote;
    IVALUE public value;
    ISPOGVault public vault;
    IERC20 public cash;
    IList public list;
    uint256 public tax;

    address public alice = createUser("alice");
    address public bob = createUser("bob");
    address public carol = createUser("carol");

    uint256 public amountToMint = 100e18;

    uint8 public noVote = 0;
    uint8 public yesVote = 1;

    enum VoteType {
        No,
        Yes
    }

    function setUp() public virtual {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = ISPOG(deployScript.spog());
        governor = ISPOGGovernor(payable(deployScript.governor()));
        cash = IERC20(deployScript.cash());
        vote = IVOTE(deployScript.vote());
        value = IVALUE(deployScript.value());
        vault = ISPOGVault(deployScript.vault());
        tax = deployScript.tax();

        // mint vote tokens and self-delegate
        vote.mint(address(this), amountToMint);
        vote.delegate(address(this));

        // mint value tokens and self-delegate
        value.mint(address(this), amountToMint);
        value.delegate(address(this));

        // deploy list and change admin to spog
        List newList = new List("SPOG List");
        newList.changeAdmin(address(spog));
        list = IList(address(newList));

        // Initialize users initial token balances
        fundUsers();
    }

    function fundUsers() internal {
        // mint VOTE and VALUE tokens to alice, bob and carol
        vote.mint(alice, amountToMint);
        value.mint(alice, amountToMint);
        vm.startPrank(alice);
        vote.delegate(alice); // self delegate
        value.delegate(alice); // self delegate
        vm.stopPrank();

        vote.mint(bob, amountToMint);
        value.mint(bob, amountToMint);
        vm.startPrank(bob);
        vote.delegate(bob); // self delegate
        value.delegate(bob); // self delegate
        vm.stopPrank();

        vote.mint(carol, amountToMint);
        value.mint(carol, amountToMint);
        vm.startPrank(carol);
        vote.delegate(carol); // self delegate
        value.delegate(carol); // self delegate
        vm.stopPrank();
    }

    /* Helper functions */
    function getProposalIdAndHashedDescription(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal view returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);
    }

    function proposeAddingNewListToSpog(string memory proposalDescription)
        internal
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addList(address)", list);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create new proposal
        cash.approve(address(spog), tax);
        // expectEmit();
        // emit NewVoteQuorumProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function addNewListToSpog() internal {
        // create proposal to add new list
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("Add new list");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

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
        calldatas[0] = abi.encodeWithSignature("append(address,address)", listToAddAddressTo, addressToAdd);
        string memory description = "Append address to a list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }

}
