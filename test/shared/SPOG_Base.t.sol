// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/governance/IGovernor.sol";

import "test/Base.t.sol";
import "script/SPOGDeploy.s.sol";

import "src/periphery/List.sol";
import "src/interfaces/tokens/ISPOGVotes.sol";

contract SPOG_Base is BaseTest {
    SPOGDeployScript public deployScript;

    address public spog;
    address public governor;
    address public vote;
    address public value;
    address public voteVault;
    address public valueVault;
    address public cash;
    address public list;

    enum VoteType {
        No,
        Yes
    }

    function setUp() public virtual {
        deployScript = new SPOGDeployScript();
        deployScript.run();

        spog = deployScript.spog();
        governor = deployScript.governor();
        cash = deployScript.cash();
        vote = deployScript.vote();
        value = deployScript.value();
        voteVault = deployScript.voteVault();
        valueVault = deployScript.valueVault();

        // mint vote tokens and self-delegate
        ISPOGVotes(vote).mint(address(this), 100e18);
        ISPOGVotes(vote).delegate(address(this));

        // mint value tokens and self-delegate
        ISPOGVotes(value).mint(address(this), 100e18);
        ISPOGVotes(value).delegate(address(this));

        // deploy list and change admin to spog
        List newList = new List("SPOG List");
        newList.changeAdmin(address(spog));
        list = address(newList);
    }

    /* Helper functions */
    function getProposalIdAndHashedDescription(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) internal view returns (bytes32 hashedDescription, uint256 proposalId) {
        hashedDescription = keccak256(abi.encodePacked(description));
        proposalId = IGovernor(governor).hashProposal(targets, values, calldatas, hashedDescription);
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
        IERC20(deployScript.cash()).approve(address(spog), deployScript.tax());
        IGovernor(governor).propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + IGovernor(governor).votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        IGovernor(governor).castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        IGovernor(governor).execute(targets, values, calldatas, hashedDescription);
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
        IERC20(deployScript.cash()).approve(address(spog), deployScript.tax());
        IGovernor(governor).propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + IGovernor(governor).votingDelay() + 1);

        // cast vote on proposal
        uint8 yesVote = 1;
        IGovernor(governor).castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        IGovernor(governor).execute(targets, values, calldatas, hashedDescription);
    }
}
