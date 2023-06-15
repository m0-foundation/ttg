// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import "test/Base.t.sol";
import "script/SPOGDeploy.s.sol";

import "src/periphery/List.sol";
import "src/interfaces/tokens/ISPOGVotes.sol";

contract SPOG_Base is BaseTest {
    string public constant _TEST_MNEMONIC = "test test test test test test test test test test test junk";

    SPOGDeployScript public deployScript;

    ISPOG public spog;
    DualGovernor public governor;
    ISPOGVotes public vote;
    ISPOGVotes public value;
    VoteVault public voteVault;
    ValueVault public valueVault;
    IList public list;
    ERC20Mock public cash;

    uint256 public tax;

    uint8 noVote = 0;
    uint8 yesVote = 1;

    address admin;
    address alice;
    address bob;
    address charlie;
    address dave;

    enum VoteType {
        No,
        Yes
    }

    function setUp() public virtual {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = ISPOG(deployScript.spog());
        governor = DualGovernor(payable(deployScript.governor()));
        vote = ISPOGVotes(deployScript.vote());
        value = ISPOGVotes(deployScript.value());
        voteVault = VoteVault(deployScript.voteVault());
        valueVault = ValueVault(deployScript.valueVault());
        tax = deployScript.tax();
        cash = ERC20Mock(deployScript.cash());

        // msg.sender can propose with cash
        cash.mint(address(this), 100e18);

        // deploy list and change admin to spog
        List newList = new List("SPOG List");
        newList.changeAdmin(address(spog));
        list = IList(address(newList));

        // setup test users
        admin = getUser(0);
        alice = getUser(1);
        bob = getUser(2);
        charlie = getUser(3);
        dave = getUser(4);
    }

    function getUser(uint32 index) internal returns (address) {
        (address user,) = deriveRememberKey({mnemonic: _TEST_MNEMONIC, index: index});
        return user;
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

        vm.prank(alice);
        governor.castVote(proposalId, yesVote);

        vm.prank(bob);
        governor.castVote(proposalId, yesVote);

        vm.prank(charlie);
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
        vm.prank(alice);
        governor.castVote(proposalId, yesVote);

        vm.prank(bob);
        governor.castVote(proposalId, yesVote);

        vm.prank(charlie);
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }
}
