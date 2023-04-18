// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";

import "forge-std/console.sol";

contract VoteTokenTest is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    // address carol = createUser("carol");

    uint256 voteTokenAmountToMint = 1000e18;
    uint256 valueTokenAmountToMint = 1000e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

    event NewSingleQuorumProposal(uint256 indexed proposalId);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /**
     * Test Functions
     */
    function test_VoteToken_balanceOf() public {
        // mint ether and value tokens to alice, bob and carol
        vm.deal({account: alice, newBalance: 10 ether});
        vm.deal({account: bob, newBalance: 10 ether});

        ValueToken valueToken = new ValueToken("SPOGValue", "value");

        // Mint initial balances to users
        valueToken.mint(alice, 50e18);
        valueToken.mint(bob, 60e18);

        // Check initial balances
        assertEq(valueToken.balanceOf(alice), 50e18);
        assertEq(valueToken.balanceOf(bob), 60e18);
        assertEq(valueToken.totalSupply(), 110e18);

        // Create new VoteToken with forked balances of ValueToken holders
        VoteToken voteToken = new VoteToken("SPOGVote", "vote", address(valueToken));

        // Check initial forked balances
        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice), 50e18);
        assertEq(voteToken.balanceOf(bob), 60e18);

        vm.startPrank(bob);
        valueToken.transfer(alice, 10e18);

        // Movements of value tokens have no effect on VoteToken balances after fork
        assertEq(valueToken.balanceOf(alice), 60e18);
        assertEq(valueToken.balanceOf(bob), 50e18);
        assertEq(voteToken.balanceOf(alice), 50e18);
        assertEq(voteToken.balanceOf(bob), 60e18);

        // Vote balances accounting works
        voteToken.transfer(alice, 50e18);

        assertEq(voteToken.totalSupply(), 110e18);
        assertEq(voteToken.balanceOf(alice), 100e18);
        assertEq(voteToken.balanceOf(bob), 10e18);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        voteToken.transfer(alice, 20e18);
    }
}
