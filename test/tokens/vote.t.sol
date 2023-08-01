// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IControlledByRegistrar } from "../../src/registrar/IControlledByRegistrar.sol";
import { IVOTE } from "../../src/tokens/ITokens.sol";

import { VALUE } from "../../src/tokens/VALUE.sol";
import { VOTE } from "../../src/tokens/VOTE.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract VoteTokenTest is SPOGBaseTest {
    address alice1 = createUser("alice1");
    address bob1 = createUser("bob1");
    address carol1 = createUser("carol1");
    address nothing = createUser("nothing");

    uint256 aliceStartBalance = 50e18;
    uint256 bobStartBalance = 60e18;
    uint256 carolStartBalance = 30e18;

    VALUE valueToken;
    VOTE voteToken;

    event ResetInitialized(uint256 indexed resetSnapshotId);
    event PreviousResetSupplyClaimed(address indexed account, uint256 amount);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        // Make sure alice, bob and carol can interact with blockchain
        vm.deal({ account: alice1, newBalance: 10 ether });
        vm.deal({ account: bob1, newBalance: 10 ether });
        vm.deal({ account: carol1, newBalance: 10 ether });
    }

    /**
     * Helpers
     */
    function initTokens() private {
        valueToken = new VALUE("SPOGValue", "value", address(registrar));

        // Mint initial balances to users
        vm.startPrank(address(governor));
        valueToken.mint(alice1, aliceStartBalance);
        valueToken.mint(bob1, bobStartBalance);
        valueToken.mint(carol1, carolStartBalance);
        vm.stopPrank();

        // Check initial balances
        assertEq(valueToken.balanceOf(alice1), aliceStartBalance);
        assertEq(valueToken.balanceOf(bob1), bobStartBalance);
        assertEq(valueToken.balanceOf(carol1), carolStartBalance);
        assertEq(valueToken.totalSupply(), 140e18);

        // Create new VoteToken
        voteToken = new VOTE("SPOGVote", "vote", address(registrar), address(valueToken));
    }

    function resetGovernance() private {
        vm.prank(address(registrar));
        uint256 snapshotId = valueToken.snapshot();

        // Reset VoteToken by Registrar
        // Do not check emitted snapshot id, just confirm that event happened
        vm.expectEmit(false, false, false, false);
        emit ResetInitialized(0);

        vm.prank(address(registrar));
        voteToken.reset(snapshotId);

        // Check initial Vote balances after reset
        assertEq(voteToken.totalSupply(), 0);
        assertEq(voteToken.balanceOf(alice1), 0);
        assertEq(voteToken.balanceOf(bob1), 0);
    }

    /**
     * Test Functions
     */
    function test_Revert_reset_WhenCallerIsNotRegistrar() public {
        initTokens();

        uint256 randomSnapshotId = 10_000;
        vm.expectRevert(IControlledByRegistrar.CallerIsNotRegistrar.selector);
        voteToken.reset(randomSnapshotId);
    }

    function test_Revert_reset_WhenResetWasInitialized() public {
        initTokens();

        uint256 randomSnapshotId = 10_000;

        vm.prank(address(registrar));
        voteToken.reset(randomSnapshotId);

        assertEq(voteToken.resetSnapshotId(), randomSnapshotId);

        vm.expectRevert(IVOTE.ResetAlreadyInitialized.selector);
        vm.prank(address(registrar));
        voteToken.reset(randomSnapshotId);
    }

    function test_Revert_ClaimPreviousSupply_WhenAlreadyClaimed() public {
        initTokens();
        resetGovernance();

        // Alice claims her tokens
        expectEmit();
        emit PreviousResetSupplyClaimed(address(alice1), aliceStartBalance);
        vm.prank(alice1);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice1), aliceStartBalance, "Alice should have 50e18 tokens");

        // Alice attempts to claim again
        vm.expectRevert(IVOTE.ResetTokensAlreadyClaimed.selector);
        vm.prank(alice1);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice1), aliceStartBalance, "Alice should have 50e18 tokens");
    }

    function test_Revert_ClaimPreviousSupply_WhenResetNotInitialized() public {
        initTokens();

        // Alice claims her tokens
        vm.expectRevert(IVOTE.ResetNotInitialized.selector);
        vm.prank(alice1);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.balanceOf(alice1), 0, "Alice should have 0 tokens");
    }

    function test_Revert_ResetBalance_WhenResetNotInitialized() public {
        initTokens();

        vm.expectRevert("ERC20Snapshot: id is 0");
        voteToken.resetBalanceOf(address(alice1));
    }

    function test_Revert_ClaimPreviousSupply_WhenNoTokensToClaim() public {
        initTokens();
        resetGovernance();

        // Nothing attempts to claim their tokens
        vm.expectRevert(IVOTE.NoResetTokensToClaim.selector);
        vm.prank(nothing);
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
        assertEq(voteToken.resetBalanceOf(address(alice1)), aliceStartBalance, "Alice reset balance is incorrect");

        vm.prank(alice1);
        voteToken.claimPreviousSupply();

        // Bob claims his tokens
        assertEq(voteToken.resetBalanceOf(address(bob1)), bobStartBalance, "Bob reset balance is incorrect");
        vm.prank(bob1);
        voteToken.claimPreviousSupply();

        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice1), aliceStartBalance);
        assertEq(voteToken.balanceOf(bob1), bobStartBalance);

        // Vote balances accounting works
        vm.prank(bob1);
        voteToken.transfer(alice1, 50e18);

        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice1), 100e18);
        assertEq(voteToken.balanceOf(bob1), 10e18);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(bob1);
        voteToken.transfer(alice1, 20e18);
    }
}
