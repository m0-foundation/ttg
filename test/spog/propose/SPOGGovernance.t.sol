// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";

contract SPOGGovernanceTest is SPOG_Base {
    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /**
     * Test Functions *******
     */

    function test_Revert_Propose_WhenMoreThanOneProposalPassed() public {
        // set data for 2 proposals at once
        address[] memory targets = new address[](2);
        targets[0] = address(spog);
        targets[1] = address(spog);
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        calldatas[1] = abi.encodeWithSignature("append(address,address)", users.bob, list);
        string memory description = "add 2 merchants to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // revert when method is not supported
        vm.expectRevert("Only 1 change per proposal");
        spog.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenEtherValueIsPassed() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // revert when proposal expects ETH value
        vm.expectRevert("No ETH value should be passed");
        spog.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenTargetIsNotSPOG() public {
        address[] memory targets = new address[](1);
        // Instead of SPOG, we are passing the list contract
        targets[0] = address(list);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // revert when proposal expects ETH value
        vm.expectRevert("Only SPOG can be target");
        spog.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_WhenMethodIsNotSupported() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewListFun(address)", list);
        string memory description = "Should not pass proposal";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        // revert when method signature is not supported
        vm.expectRevert("Method is not supported");
        spog.propose(targets, values, calldatas, description);
    }

    function test_Revert_Propose_SameProposal() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // propose
        spog.propose(targets, values, calldatas, description);

        deployScript.cash().approve(address(spog), deployScript.tax());
        vm.expectRevert("Governor: proposal already exists");
        spog.propose(targets, values, calldatas, description);
    }
}
