// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC20PricelessAuction} from "src/periphery/ERC20PricelessAuction.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import "forge-std/console.sol";


contract ERC20PricelessAuctionTest is SPOG_Base {
    ERC20PricelessAuction public auction;

    address fakeVault = createUser("vault");

    ERC20GodMode internal voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);

    function setUp() public override {
        super.setUp();

        uint256 auctionDuration = 30 days;
        vm.prank(fakeVault);
        auction = new ERC20PricelessAuction(voteToken, usdc, auctionDuration, fakeVault);
    }

    function mintTokensToVault(uint256 amount) internal {
        voteToken.mint(address(fakeVault), amount);
    }

    function test_init() public {
        mintTokensToVault(1000e18);
        
        // vault transfers tokens to auction
        vm.prank(fakeVault);
        voteToken.transfer(address(auction), 1000e18);

        // vault calls init
        vm.prank(fakeVault);
        auction.init();

        assertEq(voteToken.balanceOf(address(auction)), 1000e18);
    }

    function test_getCurrentPrice() public {
        mintTokensToVault(1000e18);
        
        // vault transfers tokens to auction
        vm.prank(fakeVault);
        voteToken.transfer(address(auction), 1000e18);

        // vault calls init
        vm.prank(fakeVault);
        auction.init();

        assertEq(auction.getCurrentPrice(), usdc.totalSupply() / 1000);

        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);
        }

        assertEq(auction.getCurrentPrice(), 1);
    }

    function test_buyTokens() public {
        mintTokensToVault(1000e18);
        
        // vault transfers tokens to auction
        vm.prank(fakeVault);
        voteToken.transfer(address(auction), 1000e18);

        // vault calls init
        vm.prank(fakeVault);
        auction.init();

        address buyer = createUser("buyer");
        
        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);

            uint256 price = auction.getCurrentPrice();

            uint256 buy = 10e18;
            if (price <= 1000e6 && voteToken.balanceOf(address(auction)) >= buy) {
                usdc.mint(buyer, buy);
                vm.prank(buyer);
                usdc.approve(address(auction), buy);

                vm.prank(buyer);
                auction.buyTokens(buy);
            }
        }

        assertEq(voteToken.balanceOf(address(auction)), auction.auctionTokenAmount() - auction.amountSold());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        bytes memory customError = abi.encodeWithSignature("AuctionEnded()");
        vm.expectRevert(customError);
        auction.buyTokens(1);

    }

    function test_withdraw() public {
       mintTokensToVault(1000e18);
        
        // vault transfers tokens to auction
        vm.prank(fakeVault);
        voteToken.transfer(address(auction), 1000e18);

        // vault calls init
        vm.prank(fakeVault);
        auction.init();
        
        bytes memory customError = abi.encodeWithSignature("AuctionNotEnded()");
        vm.expectRevert(customError);
        auction.withdraw(voteToken);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30 days - 1 seconds);

        vm.expectRevert(customError);
        auction.withdraw(voteToken);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 seconds);

        auction.withdraw(voteToken);

        assertEq(voteToken.balanceOf(address(auction)),0);
    }
}
