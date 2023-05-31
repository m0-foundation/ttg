// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract Vault_IntegratedWithSPOG is SPOG_Base {
    address alice = createUser("alice");
    address bob = createUser("bob");
    address carol = createUser("carol");

    uint256 amountToMint = 100e18;
    uint8 noVote = 0;
    uint8 yesVote = 1;

    function setUp() public override {
        super.setUp();

        // mint ether and vote and value to alice, bob and carol
        vm.deal({account: alice, newBalance: 100 ether});
        vote.mint(alice, amountToMint);
        value.mint(alice, amountToMint);
        vm.startPrank(alice);
        vote.delegate(alice); // self delegate
        value.delegate(alice); // self delegate
        vm.stopPrank();

        vm.deal({account: bob, newBalance: 100 ether});
        vote.mint(bob, amountToMint);
        value.mint(bob, amountToMint);
        vm.startPrank(bob);
        vote.delegate(bob); // self delegate
        value.delegate(bob); // self delegate
        vm.stopPrank();

        vm.deal({account: carol, newBalance: 100 ether});
        vote.mint(carol, amountToMint);
        value.mint(carol, amountToMint);
        vm.startPrank(carol);
        vote.delegate(carol); // self delegate
        value.delegate(carol); // self delegate
        vm.stopPrank();
    }
}
