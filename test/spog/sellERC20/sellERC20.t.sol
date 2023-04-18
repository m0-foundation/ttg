// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract SPOG_SellERC20 is SPOG_Base {
    function test_SPOGProposalToSellERC20() public {
        // setup
        dai.mint(address(spog.vault()), 1000e18);

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(dai), 1000e18);
        string memory description = "Sell ERC20";

        (, uint256 proposalId) =
            getProposalIdAndHashedDescription(valueGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            valueGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );
    }

    function test_SPOGProposalToSellERC20WithAddressZero() public {
        // setup
        dai.mint(address(spog.vault()), 1000e18);

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(0), 1000e18);
        string memory description = "Sell ERC20";

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        bytes memory customError = abi.encodeWithSignature("InvalidProposal()");
        vm.expectRevert(customError);

        spog.propose(targets, values, calldatas, description);
    }

    function test_SPOGProposalToSellERC20WithAmountZero() public {
        // setup
        dai.mint(address(spog.vault()), 1000e18);

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(dai), 0);
        string memory description = "Sell ERC20";

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        bytes memory customError = abi.encodeWithSignature("InvalidProposal()");
        vm.expectRevert(customError);

        spog.propose(targets, values, calldatas, description);
    }

    function test_SPOGProposalToSellERC20VoteToken() public {
        // setup
        dai.mint(address(spog.vault()), 1000e18);

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(spog.voteGovernor().votingToken()), 1);
        string memory description = "Sell ERC20";

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        bytes memory customError = abi.encodeWithSignature("InvalidProposal()");
        vm.expectRevert(customError);

        spog.propose(targets, values, calldatas, description);
    }

    function test_SPOGProposalToSellERC20WithZeroBalance() public {
        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(dai), 1000e18);
        string memory description = "Sell ERC20";

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        
        bytes memory customError = abi.encodeWithSignature("InvalidProposal()");
        vm.expectRevert(customError);

        spog.propose(targets, values, calldatas, description);
    }

    function test_SPOGExecuteProposalToSellERC20() public {
        // setup
        dai.mint(address(spog.vault()), 1000e18);

        // create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("sellERC20(address,uint256)", address(dai), 1000e18);
        string memory description = "Sell ERC20";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(valueGovernor, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(targets, values, calldatas, description);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(
            valueGovernor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state"
        );

         // fast forward to an active voting period
        vm.roll(block.number + valueGovernor.votingDelay() + 1);

        // proposal should be active now
        assertTrue(valueGovernor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // check proposal is not yet succeeded
        assertFalse(valueGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Already in succeeded state");

        // cast vote on proposal
        uint8 yesVote = uint8(VoteType.Yes);
        valueGovernor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        // check proposal is succeeded
        assertTrue(valueGovernor.state(proposalId) == IGovernor.ProposalState.Succeeded, "Not in succeeded state");

        // execute proposal
        spog.execute(targets, values, calldatas, hashedDescription);

        // check proposal is executed
        assertTrue(valueGovernor.state(proposalId) == IGovernor.ProposalState.Executed, "Proposal not executed");

    }
}
