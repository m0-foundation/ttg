// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SPOG_fileWithDoubleQuorum is SPOG_Base {
    bytes32 internal reward;
    bytes internal elevenAsCalldataValue;
    uint8 internal yesVote;

    function setUp() public override {
        reward = "reward";
        elevenAsCalldataValue = abi.encode(11);
        yesVote = 1;

        super.setUp();
    }

    function test_Revert_FileWhenNotCallingFromGovernance()
        public
    {
        vm.expectRevert("SPOG: Only GovSPOG");
        spog.fileWithDoubleQuorum(reward, elevenAsCalldataValue);
    }

    function test_Revert_FileMustBeProposedByVoteHoldersFirst()
        public
    {
        // value holders vote on proposal
        address[] memory targetsForValueHolders = new address[](1);
        targetsForValueHolders[0] = address(spog);
        uint256[] memory valuesForValueHolders = new uint256[](1);
        valuesForValueHolders[0] = 0;
        bytes[] memory calldatasForValueHolders = new bytes[](1);

        calldatasForValueHolders[0] = abi.encodeWithSignature(
            "fileWithDoubleQuorum(bytes32,bytes)",
            reward,
            elevenAsCalldataValue
        );
        string
            memory descriptionForValueHolders = "GovSPOGValue change reward variable in spog";

        (
            bytes32 hashedDescriptionForValueHolders,
            uint256 proposalIdForValueHolders
        ) = getProposalIdAndHashedDescription(
                govSPOGValue,
                targetsForValueHolders,
                valuesForValueHolders,
                calldatasForValueHolders,
                descriptionForValueHolders
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            descriptionForValueHolders
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        vm.expectRevert("SPOG: Double quorum not met");
        govSPOGValue.execute(
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            hashedDescriptionForValueHolders
        );

        (, , , , uint256 rewardSecondCheck, ) = spog.spogData();
        // assert that reward was not modified
        assertTrue(
            rewardSecondCheck == deployScript.reward(),
            "Reward must not be changed"
        );
    }

    function test_File_SPOGProposalToChangeVariableInSpog()
        public
    {
        // create proposal to change variable in spog
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature(
            "fileWithDoubleQuorum(bytes32,bytes)",
            reward,
            elevenAsCalldataValue
        );
        string memory description = "Change reward variable in spog";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                govSPOGVote,
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGVote)),
            targets,
            values,
            calldatas,
            description
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        bytes32 identifier = keccak256(
            abi.encodePacked(reward, elevenAsCalldataValue)
        );
        // check that DoubleQuorumInitiated event was triggered
        expectEmit();
        emit DoubleQuorumInitiated(identifier);
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        (, , , , uint256 rewardFirstCheck, ) = spog.spogData();

        // assert that reward has not been changed yet as it needs to be voted on again by value holders
        assertFalse(
            rewardFirstCheck == 11,
            "Reward should not have been changed"
        );

        /**********  value holders vote on proposal **********/
        vm.warp(1 hours);

        (
            bytes32 hashedDescriptionForValueHolders,
            uint256 proposalIdForValueHolders
        ) = getProposalIdAndHashedDescription(
                govSPOGValue,
                targets,
                values,
                calldatas,
                description
            );

        // must update start of next voting period so as to not revert on votingDelay() check
        while (block.number >= govSPOGValue.startOfNextVotingPeriod()) {
            govSPOGValue.updateStartOfNextVotingPeriod();
        }

        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        // check that DoubleQuorumFinalized event was triggered
        expectEmit();
        emit DoubleQuorumFinalized(identifier);
        govSPOGValue.execute(
            targets,
            values,
            calldatas,
            hashedDescriptionForValueHolders
        );

        (, , , , uint256 rewardSecondCheck, ) = spog.spogData();
        // assert that reward was modified by double quorum
        assertTrue(rewardSecondCheck == 11, "Reward was not changed");
    }

    function test_File_ChangeCashToken_SPOGProposalToChangeVariableInSpog()
        public
    {
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

        calldatas[0] = abi.encodeWithSignature(
            "fileWithDoubleQuorum(bytes32,bytes)",
            cash,
            newCash
        );
        string memory description = "Change cash variable in spog";

        (
            bytes32 hashedDescription,
            uint256 proposalId
        ) = getProposalIdAndHashedDescription(
                govSPOGVote,
                targets,
                values,
                calldatas,
                description
            );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGVote)),
            targets,
            values,
            calldatas,
            description
        );

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        bytes32 identifier = keccak256(abi.encodePacked(cash, newCash));
        // check that DoubleQuorumInitiated event was triggered
        expectEmit();
        emit DoubleQuorumInitiated(identifier);
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        (, , , , , IERC20 cashFirstCheck) = spog.spogData();

        // assert that cash has not been changed yet as it needs to be voted on again by value holders
        assertFalse(
            address(cashFirstCheck) == address(newCashInstance),
            "Reward should not have been changed"
        );
        assertTrue(
            address(cashFirstCheck) == address(deployScript.cash()),
            "Cash was changed"
        );

        /**********  value holders vote on proposal **********/
        vm.warp(1 hours);

        (
            bytes32 hashedDescriptionForValueHolders,
            uint256 proposalIdForValueHolders
        ) = getProposalIdAndHashedDescription(
                govSPOGValue,
                targets,
                values,
                calldatas,
                description
            );

        // must update start of next voting period so as to not revert on votingDelay() check
        while (block.number >= govSPOGValue.startOfNextVotingPeriod()) {
            govSPOGValue.updateStartOfNextVotingPeriod();
        }

        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        // check that DoubleQuorumFinalized event was triggered
        expectEmit();
        emit DoubleQuorumFinalized(identifier);
        govSPOGValue.execute(
            targets,
            values,
            calldatas,
            hashedDescriptionForValueHolders
        );

        (, , , , , IERC20 cashSecondCheck) = spog.spogData();
        // assert that cash was modified by double quorum
        assertTrue(
            address(cashSecondCheck) == address(newCashInstance),
            "Reward was not changed"
        );
    }
}
