// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IControlledByComptroller } from "../../src/comptroller/IControlledByComptroller.sol";

import { VALUE } from "../../src/tokens/VALUE.sol";

import { ERC20Snapshot } from "../ImportedContracts.sol";
import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract ValueTokenTest is SPOGBaseTest {
    uint256 aliceStartBalance = 50e18;

    VALUE valueToken;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        valueToken = new VALUE("SPOGValue", "value", address(comptroller));

        // Alice can interact with blockchain
        vm.deal({ account: alice, newBalance: 10 ether });
    }

    function test_Revert_Snapshot_WhenCallerIsNotComptroller() public {
        vm.expectRevert(IControlledByComptroller.CallerIsNotComptroller.selector);
        valueToken.snapshot();
    }

    function test_snapshot() public {
        // Mint initial balance for alice
        vm.prank(address(governor));
        valueToken.mint(alice, aliceStartBalance);
        assertEq(valueToken.balanceOf(alice), aliceStartBalance);

        // Comptroller takes snapshot
        vm.prank(address(comptroller));
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
}
