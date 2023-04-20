// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

contract SPOG_reset is SPOG_Base {
    uint8 internal yesVote;
    uint8 internal noVote;

    event NewValueQuorumProposal(uint256 indexed proposalId);
    event SPOGResetExecuted(address indexed newVoteToken, address indexed newVoteGovernor);

    function setUp() public override {
        yesVote = 1;
        noVote = 0;

        super.setUp();
    }

    /**
     * Helpers *******
     */
    function proposeGovernanceReset(string memory proposalDescription)
        private
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("reset()");
        string memory description = proposalDescription;
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = valueGovernor.hashProposal(targets, values, calldatas, hashedDescription);

        // create proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // Check the event is emitted
        expectEmit();
        emit NewValueQuorumProposal(proposalId);

        uint256 spogProposalId = spog.propose(callData, description);
        assertTrue(spogProposalId == proposalId, "spog proposal id does not match vote governor proposal id");

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function test_Revert_Change_WhenNotCalledFromGovernance() public {
        vm.expectRevert("SPOG: Only value governor");
        spog.reset();
    }

    function test_Reset_Success() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeGovernanceReset("Propose reset of vote governance");

        // fast forward to an active voting period
        vm.roll(block.number + valueGovernor.votingDelay() + 1);

        // value holders vote on proposal
        valueGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        address voteGovernorBeforeFork = address(spog.voteGovernor());

        vm.expectEmit(false, false, false, false);
        address anyAddress = address(0);
        emit SPOGResetExecuted(anyAddress, anyAddress);
        spog.execute(targets, values, calldatas, hashedDescription);

        assertFalse(address(spog.voteGovernor()) == voteGovernorBeforeFork, "Vote governor was not reset");
    }

    // function test_Change_ChangeCashToken_SPOGProposalToChangeVariableInSpog() public {
    //     ERC20GodMode newCashInstance = new ERC20GodMode(
    //         "New Cash",
    //         "NCASH",
    //         18
    //     );
    //     bytes32 cash = "cash";
    //     bytes memory newCash = abi.encode(address(newCashInstance));

    //     // create proposal to change variable in spog
    //     address[] memory targets = new address[](1);
    //     targets[0] = address(spog);
    //     uint256[] memory values = new uint256[](1);
    //     values[0] = 0;
    //     bytes[] memory calldatas = new bytes[](1);

    //     calldatas[0] = abi.encodeWithSignature("change(bytes32,bytes)", cash, newCash);
    //     string memory description = "Change cash variable in spog";

    //     (bytes32 hashedDescription, uint256 proposalId) =
    //         getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

    //     // create proposal
    //     deployScript.cash().approve(address(spog), deployScript.tax());
    //     spog.propose(targets, values, calldatas, description);

    //     // fast forward to an active voting period
    //     vm.roll(block.number + voteGovernor.votingDelay() + 1);

    //     // vote holders vote on proposal
    //     voteGovernor.castVote(proposalId, yesVote);
    //     // value holders vote on proposal
    //     valueGovernor.castVote(proposalId, yesVote);

    //     // fast forward to end of voting period
    //     vm.roll(block.number + deployScript.voteTime() + 1);

    //     bytes32 identifier = keccak256(abi.encodePacked(cash, newCash));
    //     // check that DoubleQuorumFinalized event was triggered
    //     expectEmit();
    //     emit DoubleQuorumFinalized(identifier);
    //     spog.execute(targets, values, calldatas, hashedDescription);

    //     (,,,,,, IERC20 cashFirstCheck) = spog.spogData();

    //     // assert that cash has been changed
    //     assertTrue(address(cashFirstCheck) == address(newCashInstance), "Cash token was not changed");
    // }
}
