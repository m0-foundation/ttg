// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {PriceDiscoveryAuction} from "src/periphery/ERC20PriceDiscoveryAuction.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import "forge-std/console.sol";


contract ERC20DutchAuctionTest is SPOG_Base {
    PriceDiscoveryAuction public dutchAuction;

    address fakeVault = createUser("vault");

    ERC20GodMode internal voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);

    function setUp() public override {
        super.setUp();

        uint256 auctionDuration = 30 days;
        dutchAuction = new PriceDiscoveryAuction(voteToken, usdc, auctionDuration, fakeVault);
    }

    function mintAndApproveVoteTokens(uint256 amount) internal {
        voteToken.mint(address(fakeVault), amount);
        vm.prank(fakeVault);
        voteToken.approve(address(dutchAuction), amount);
    }

    function test_depositFromVault() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.depositFromVault(1000e18);
        assertEq(voteToken.balanceOf(address(dutchAuction)), 1000e18);
    }

    function test_getCurrentPrice() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.depositFromVault(1000e18);
        assertEq(dutchAuction.getCurrentPrice(), usdc.totalSupply());

        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);

            // console.log('block timestamp', block.timestamp, 'number', block.number);
            // console.log('current price', dutchAuction.getCurrentPrice());
            // console.log(block.number);

            // assertEq(dutchAuction.getCurrentPrice(), usdc.totalSupply());

        }

        assertEq(dutchAuction.getCurrentPrice(), 1);
    }

    function test_buyTokens() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.depositFromVault(1000e18);
        address buyer = createUser("buyer");
        
        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);


            if (dutchAuction.getCurrentPrice() <= 1e6) {
                console.log('price', dutchAuction.getCurrentPrice(), 'buying', 1e18);
                usdc.mint(buyer, 10e6);
                vm.prank(buyer);
                usdc.approve(address(dutchAuction), 10e6);

                vm.prank(buyer);
                dutchAuction.buyTokens(1e18);
            }
        }

        assertEq(voteToken.balanceOf(address(dutchAuction)), dutchAuction.auctionTokenAmount() - dutchAuction.amountSold());
    }

    function test_withdraw() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.depositFromVault(1000e18);

        vm.expectRevert("Auction not yet ended");
        dutchAuction.withdraw();
                
        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);
        }

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        dutchAuction.withdraw();

        assertEq(voteToken.balanceOf(address(dutchAuction)),0);
    }
}
