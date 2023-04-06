// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SPOG_change is SPOG_Base {
    bytes32 internal reward;
    bytes internal elevenAsCalldataValue;
    uint8 internal yesVote;

    event DoubleQuorumInitiated(bytes32 indexed identifier);
    event DoubleQuorumFinalized(bytes32 indexed identifier);

    function setUp() public override {
        reward = "reward";
        elevenAsCalldataValue = abi.encode(11);
        yesVote = 1;

        super.setUp();
    }

    function test_Revert_ChangeWhenNotCalledFromGovernance() public {
        vm.expectRevert("SPOG: Only vote governor");
        spog.change(reward, elevenAsCalldataValue);
    }

    function test_Revert_WhenPassingAnIncorrectParamsToChange() public {
        bytes32 incorrectParams = "tax";

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("change(bytes32,bytes)", incorrectParams, elevenAsCalldataValue);
        string memory description = "Change tax which should not be possible to change with double quorum";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // vote holders vote on proposal
        voteGovernor.castVote(proposalId, yesVote);

        // value holders vote on proposal
        valueGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // another way to get custom error selector:
        vm.expectRevert(abi.encodeWithSelector(ISPOG.InvalidParameter.selector, incorrectParams));
        spog.execute(targets, values, calldatas, hashedDescription);

        // assert that tax was not modified
        (uint256 tax,,,,,,) = spog.spogData();
        assertFalse(tax == 11, "Tax should not have been changed");
    }

    function test_Change_SPOGProposalToChangeVariableInSpog() public {
        // create proposal to change variable in spog
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("change(bytes32,bytes)", reward, elevenAsCalldataValue);
        string memory description = "Change reward variable in spog";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // create proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // vote holders vote on proposal
        voteGovernor.castVote(proposalId, yesVote);
        // value holders vote on proposal
        valueGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        bytes32 identifier = keccak256(abi.encodePacked(reward, elevenAsCalldataValue));
        // check that DoubleQuorumFinalized event was triggered
        expectEmit();
        emit DoubleQuorumFinalized(identifier);
        spog.execute(targets, values, calldatas, hashedDescription);

        (,,,,, uint256 rewardFirstCheck,) = spog.spogData();

        // assert that reward been changed
        assertTrue(rewardFirstCheck == 11, "Reward should have been changed");
    }

    function test_Change_ChangeCashToken_SPOGProposalToChangeVariableInSpog() public {
        ERC20GodMode newCashInstance = new ERC20GodMode(
            "New Cash",
            "NCASH",
            18
        );
        bytes32 cash = "cash";
        bytes memory newCash = abi.encode(address(newCashInstance));

        // create proposal to change variable in spog
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("change(bytes32,bytes)", cash, newCash);
        string memory description = "Change cash variable in spog";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(voteGovernor, targets, values, calldatas, description);

        // create proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // vote holders vote on proposal
        voteGovernor.castVote(proposalId, yesVote);
        // value holders vote on proposal
        valueGovernor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        bytes32 identifier = keccak256(abi.encodePacked(cash, newCash));
        // check that DoubleQuorumFinalized event was triggered
        expectEmit();
        emit DoubleQuorumFinalized(identifier);
        spog.execute(targets, values, calldatas, hashedDescription);

        (,,,,,, IERC20 cashFirstCheck) = spog.spogData();

        // assert that cash has been changed
        assertTrue(address(cashFirstCheck) == address(newCashInstance), "Cash token was not changed");
    }
}
