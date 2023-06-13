// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract ValueTokenTest is SPOG_Base {
    address alice = createUser("alice");
    uint256 aliceStartBalance = 50e18;

    ValueToken valueToken;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        valueToken = new ValueToken("SPOGValue", "value");
        valueToken.initializeSPOG(address(spog));

        // grant mint role to this contract
        IAccessControl(address(valueToken)).grantRole(valueToken.MINTER_ROLE(), address(this));

        // Alice can interact with blockchain
        vm.deal({account: alice, newBalance: 10 ether});
    }

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
        address user = createUser("user");

        // test mint
        valueToken.mint(user, 100);

        assertEq(valueToken.balanceOf(user), 100);

        // test burn
        vm.prank(user);
        valueToken.burn(50);

        assertEq(valueToken.balanceOf(user), 50);

        // test burnFrom
        address user2 = createUser("user2");

        vm.prank(user);
        valueToken.approve(user2, 25);

        vm.prank(user2);
        valueToken.burnFrom(user, 25);

        assertEq(valueToken.balanceOf(user), 25);
    }
}
