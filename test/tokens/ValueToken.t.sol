// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";

contract ValueTokenTest is SPOG_Base {
    address alice = createUser("alice");
    uint256 aliceStartBalance = 50e18;

    ValueToken valueToken;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        valueToken = new ValueToken("SPOGValue", "value");
        valueToken.initSPOGAddress(address(spog));

        // Alice can interact with blockchain
        vm.deal({account: alice, newBalance: 10 ether});
    }

    /**
     * Test Functions
     */
    function test_Revert_Snapshot_WhenCallerIsNotSPOG() public {
        vm.expectRevert(SPOGVotes.CallerIsNotSPOG.selector);
        valueToken.snapshot();
    }

    function test_snapshot() public {
        // Mint initial balance for alice
        valueToken.mint(alice, aliceStartBalance);
        assertEq(valueToken.balanceOf(alice), aliceStartBalance);

        // SPOG takes snapshot
        vm.startPrank(address(spog));
        uint256 snapshotId = valueToken.snapshot();

        uint256 aliceSnapshotBalance = ERC20Snapshot(valueToken).balanceOfAt(address(alice), snapshotId);
        assertEq(aliceSnapshotBalance, aliceStartBalance, "Alice snapshot balance is incorrect");
    }

    function test_MintAndBurn() public {
        ValueToken valToken = new ValueToken("SPOGVotes", "SPOGVotes");

        address user = createUser("user");

        // test mint
        valToken.mint(user, 100);

        assertEq(valToken.balanceOf(user), 100);

        // test burn
        vm.prank(user);
        valToken.burn(50);

        assertEq(valToken.balanceOf(user), 50);

        // test burnFrom
        address user2 = createUser("user2");

        vm.prank(user);
        valToken.approve(user2, 25);

        vm.prank(user2);
        valToken.burnFrom(user, 25);

        assertEq(valToken.balanceOf(user), 25);
    }
}
