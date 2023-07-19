// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IERC20, IAccessControl } from "../interfaces/ImportedInterfaces.sol";

import { ISPOG } from "../../src/interfaces/ISPOG.sol";
import { ISPOGGovernor } from "../../src/interfaces/ISPOGGovernor.sol";
import { ISPOGVault } from "../../src/interfaces/periphery/ISPOGVault.sol";
import { IVOTE, IVALUE } from "../../src/interfaces/ITokens.sol";

import { VOTE } from "../../src/tokens/VOTE.sol";
import { DualGovernor } from "../../src/core/governor/DualGovernor.sol";

import { SPOGDeployScript } from "../../script/SPOGDeploy.s.sol";
import { BaseTest } from "./BaseTest.t.sol";

contract SPOGBaseTest is BaseTest {
    bytes32 public constant LIST_NAME = "Some List";

    SPOGDeployScript public deployScript;

    ISPOG public spog;
    ISPOGGovernor public governor;
    IVOTE public vote;
    IVALUE public value;
    ISPOGVault public vault;
    IERC20 public cash;
    uint256 public tax;

    address public alice = createUser("alice");
    address public bob = createUser("bob");
    address public carol = createUser("carol");

    address public addressToChange = address(0x1234);

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
        governor = ISPOGGovernor(deployScript.governor());
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

    function getProposalIdAndHashedDescription(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal view returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);
    }

    function proposeAddingAnAddressToList(
        address account
    )
        internal
        returns (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        )
    {
        // create proposal to add address to list
        targets = new address[](1);
        targets[0] = address(spog);
        values = new uint256[](1);
        values[0] = 0;
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addToList(bytes32,address)", LIST_NAME, account);
        string memory description = "Add an address to a list";

        (hashedDescription, proposalId) = getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), tax);
        governor.propose(targets, values, calldatas, description);
    }

    function addAnAddressToList() internal returns (uint256 proposalId, address account) {
        account = makeAddr("someAddress");

        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;
        bytes32 hashedDescription;

        (proposalId, targets, values, calldatas, hashedDescription) = proposeAddingAnAddressToList(account);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function proposeEmergencyAppend(
        address account
    ) internal returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32) {
        // the actual proposal to wrap as an emergency
        bytes memory callData = abi.encode(LIST_NAME, account);

        // the emergency proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "emergency(uint8,bytes)",
            uint8(ISPOG.EmergencyType.AddToList),
            callData
        );

        string memory description = "Emergency add of merchant";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        cash.approve(address(spog), tax);

        // TODO: Check that `NewEmergencyProposal` event is emitted
        // expectEmit();
        // emit NewEmergencyProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function proposeReset(
        string memory proposalDescription,
        address valueToken
    ) internal returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32) {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        address newGovernor = createNewGovernor(valueToken);
        bytes memory callData = abi.encodeWithSignature("reset(address)", newGovernor);
        string memory description = proposalDescription;
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create proposal
        cash.approve(address(spog), 12 * deployScript.tax());

        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);

        // Make sure the proposal is immediately (+1 block) votable
        assertEq(governor.proposalSnapshot(proposalId), block.number + 1);

        assertTrue(spogProposalId == proposalId, "spog proposal id does not match value governor proposal id");

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function createNewGovernor(address valueToken) internal returns (address) {
        // deploy vote governor from factory
        VOTE newVoteToken = new VOTE("new SPOGVote", "vote", valueToken);
        // grant minter role to new voteToken deployer
        IAccessControl(address(newVoteToken)).grantRole(newVoteToken.MINTER_ROLE(), address(this));

        uint256 time = 15; // in blocks
        uint256 voteQuorum = 5;
        uint256 valueQuorum = 5;

        DualGovernor newGovernor = new DualGovernor(
            "new SPOGGovernor",
            address(newVoteToken),
            valueToken,
            voteQuorum,
            valueQuorum,
            time
        );

        return address(newGovernor);
    }

    function proposeTaxRangeChange(
        string memory proposalDescription
    ) internal returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32) {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("changeTaxRange(uint256,uint256)", 10e18, 12e18);
        string memory description = proposalDescription;
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // uint256 epoch = governor.currentEpoch();

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        return (proposalId, targets, values, calldatas, hashedDescription);
    }
}
