// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract VoteTokenTest is SPOG_Base {
    address nothing = createUser("nothing");

    uint256 aliceStartBalance = 50e18;
    uint256 bobStartBalance = 60e18;
    uint256 charlieStartBalance = 30e18;

    ValueToken valueToken;
    VoteToken voteToken;

    event ResetInitialized(uint256 indexed resetSnapshotId);
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        // Make sure alice, bob and charlie can interact with blockchain
        vm.deal({account: alice, newBalance: 10 ether});
        vm.deal({account: bob, newBalance: 10 ether});
        vm.deal({account: charlie, newBalance: 10 ether});
    }

    /**
     * Helpers
     */
    function initTokens() private {
        valueToken = new ValueToken("SPOGValue", "value");

        // Mint initial balances to users
        valueToken.mint(alice, aliceStartBalance);
        valueToken.mint(bob, bobStartBalance);
        valueToken.mint(charlie, charlieStartBalance);

        valueToken.transferOwnership(address(spog));

        // Check initial balances
        assertEq(valueToken.balanceOf(alice), aliceStartBalance);
        assertEq(valueToken.balanceOf(bob), bobStartBalance);
        assertEq(valueToken.balanceOf(charlie), charlieStartBalance);
        assertEq(valueToken.totalSupply(), 140e18);

        // Create new VoteToken
        voteToken = new VoteToken("SPOGVote", "vote", address(valueToken));
    }

    function resetGovernance() private {
        vm.startPrank(address(spog));

        uint256 snapshotId = valueToken.snapshot();

        // Reset VoteToken by SPOG
        // Do not check emitted snapshot id, just confirm that event happened
        vm.expectEmit(false, false, false, false);
        emit ResetInitialized(0);
        voteToken.reset(snapshotId);
        vm.stopPrank();

        // Check initial Vote balances after reset
        assertEq(voteToken.totalSupply(), 0);
        assertEq(voteToken.balanceOf(alice), 0);
        assertEq(voteToken.balanceOf(bob), 0);
    }

    /**
     * Test Functions
     */
    function test_Revert_reset_WhenCallerIsNotSPOG() public {
        initTokens();

        uint256 randomSnapshotId = 10000;
        vm.expectRevert("Ownable: caller is not the owner");
        voteToken.reset(randomSnapshotId);
    }

    function test_Revert_reset_WhenResetWasInitialized() public {
        initTokens();

        uint256 randomSnapshotId = 10000;
        vm.startPrank(address(spog));
        voteToken.reset(randomSnapshotId);

        assertEq(voteToken.resetSnapshotId(), randomSnapshotId);

        vm.expectRevert(IVote.ResetAlreadyInitialized.selector);
        voteToken.reset(randomSnapshotId);
    }

    function test_Revert_ClaimPreviousSupply_WhenAlreadyClaimed() public {
        initTokens();
        resetGovernance();

        // Alice claims her tokens
        vm.startPrank(alice);
        expectEmit();
        emit PreviousResetSupplyClaimed(address(alice), aliceStartBalance);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice), aliceStartBalance, "Alice should have 50e18 tokens");

        // Alice attempts to claim again
        vm.expectRevert(IVote.ResetTokensAlreadyClaimed.selector);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice), aliceStartBalance, "Alice should have 50e18 tokens");
    }

    function test_Revert_ClaimPreviousSupply_WhenResetNotInitialized() public {
        initTokens();

        // Alice claims her tokens
        vm.startPrank(alice);
        vm.expectRevert(IVote.ResetNotInitialized.selector);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice), 0, "Alice should have 0 tokens");
    }

    function test_Revert_ResetBalance_WhenResetNotInitialized() public {
        initTokens();

        vm.expectRevert("ERC20Snapshot: id is 0");
        voteToken.resetBalanceOf(address(alice));
    }

    function test_Revert_ClaimPreviousSupply_WhenNoTokensToClaim() public {
        initTokens();
        resetGovernance();

        // Nothing attempts to claim their tokens
        vm.startPrank(nothing);
        vm.expectRevert(IVote.NoResetTokensToClaim.selector);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(nothing), 0, "Balance stays 0");
    }

    function test_balances_beforeAndAfterReset() public {
        initTokens();
        resetGovernance();

        // Check initial balances after reset
        assertEq(voteToken.totalSupply(), 0);
        assertEq(voteToken.balanceOf(alice), 0);
        assertEq(voteToken.balanceOf(bob), 0);

        // Alice claims her tokens
        vm.startPrank(alice);
        assertEq(voteToken.resetBalanceOf(address(alice)), aliceStartBalance, "Alice reset balance is incorrect");
        voteToken.claimPreviousSupply();
        vm.stopPrank();

        // Bob claims his tokens
        vm.startPrank(bob);
        assertEq(voteToken.resetBalanceOf(address(bob)), bobStartBalance, "Bob reset balance is incorrect");
        voteToken.claimPreviousSupply();
        vm.stopPrank();

        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice), aliceStartBalance);
        assertEq(voteToken.balanceOf(bob), bobStartBalance);

        vm.startPrank(bob);

        // Vote balances accounting works
        voteToken.transfer(alice, 50e18);

        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice), 100e18);
        assertEq(voteToken.balanceOf(bob), 10e18);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        voteToken.transfer(alice, 20e18);
    }
}
