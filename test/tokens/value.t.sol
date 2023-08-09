// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IControlledByRegistrar } from "../../src/registrar/IControlledByRegistrar.sol";

import { VALUE } from "../../src/tokens/VALUE.sol";

import { ERC20Snapshot } from "../ImportedContracts.sol";
import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract ValueTokenTest is SPOGBaseTest {
    uint256 aliceStartBalance = 50e18;

    VALUE valueToken;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        valueToken = new VALUE("SPOGValue", "value", address(registrar));

        // Alice can interact with blockchain
        vm.deal({ account: alice, newBalance: 10 ether });
    }

    function test_Revert_Snapshot_WhenCallerIsNotRegistrar() public {
        vm.expectRevert(IControlledByRegistrar.CallerIsNotRegistrar.selector);
        valueToken.snapshot();
    }

    function test_snapshot() public {
        // Mint initial balance for alice
        vm.prank(address(governor));
        valueToken.mint(alice, aliceStartBalance);
        assertEq(valueToken.balanceOf(alice), aliceStartBalance);

        // Registrar takes snapshot
        vm.prank(address(registrar));
        uint256 snapshotId = valueToken.snapshot();

        uint256 aliceSnapshotBalance = ERC20Snapshot(valueToken).balanceOfAt(address(alice), snapshotId);
        assertEq(aliceSnapshotBalance, aliceStartBalance, "Alice snapshot balance is incorrect");
    }

    function test_MintAndBurn() public {
        address user = createUser("user");

        // test mint
        vm.prank(address(governor));
        valueToken.mint(user, 100);

        assertEq(valueToken.balanceOf(user), 100);
    }

    function testAutomaticSelfDelegationOnMint() public {
        address user = createUser("user");

        // mint tokens to the user
        vm.prank(address(governor));
        valueToken.mint(user, 100);

        // ensure that they are auto-self-delegated
        assertEq(valueToken.delegates(user), user);
        assertEq(valueToken.getVotes(user), 100);
    }

    function testAutomaticSelfDelegationOnTransfer() public {
        address user1 = createUser("user1");
        address user2 = createUser("user2");

        // mint tokens to the user
        vm.prank(address(governor));
        valueToken.mint(user1, 100);

        // user1 transfers to user2; they should be delegated to self
        vm.prank(user1);
        valueToken.transfer(user2, 100);
        assertEq(valueToken.delegates(user1), user1);
        assertEq(valueToken.delegates(user2), user2);
        assertEq(valueToken.getVotes(user1), 0);
        assertEq(valueToken.getVotes(user2), 100);
    
        // user2 delegates to user1
        vm.prank(user2);
        valueToken.delegate(user1);
        assertEq(valueToken.delegates(user1), user1);
        assertEq(valueToken.delegates(user2), user1);
        assertEq(valueToken.getVotes(user1), 100);
        assertEq(valueToken.getVotes(user2), 0);

        // user2 transfers 50 tokens to user1
        vm.prank(user2);
        valueToken.transfer(user1, 50);
        assertEq(valueToken.delegates(user1), user1);
        assertEq(valueToken.delegates(user2), user1);
        assertEq(valueToken.getVotes(user1), 100);
        assertEq(valueToken.getVotes(user2), 0);

        // user1 transfer 1 token to user2
        vm.prank(user1);
        valueToken.transfer(user2, 1);
        assertEq(valueToken.delegates(user1), user1);
        assertEq(valueToken.delegates(user2), user1);
        assertEq(valueToken.getVotes(user1), 100);
        assertEq(valueToken.getVotes(user2), 0);
    }
}
