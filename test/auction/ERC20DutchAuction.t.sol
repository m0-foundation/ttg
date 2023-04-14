// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {DutchAuction} from "src/periphery/ERC20DutchAuction.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import "forge-std/console.sol";


contract ERC20DutchAuctionTest is SPOG_Base {
    DutchAuction public dutchAuction;

    address fakeVault = createUser("vault");

    ERC20GodMode internal voteToken = new ERC20GodMode("Vote Token", "VOTE", 18);

    function setUp() public override {
        super.setUp();

        uint256 auctionDuration = 30 days;
        dutchAuction = new DutchAuction(voteToken, usdc, auctionDuration, fakeVault);
    }

    function mintAndApproveVoteTokens(uint256 amount) internal {
        voteToken.mint(address(fakeVault), amount);
        vm.prank(fakeVault);
        voteToken.approve(address(dutchAuction), amount);
    }

    function test_init() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.init(1000e18);
        assertEq(voteToken.balanceOf(address(dutchAuction)), 1000e18);
    }

    function test_getCurrentPrice() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.init(1000e18);
        assertEq(dutchAuction.getCurrentPrice(), usdc.totalSupply());

        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);
        }

        assertEq(dutchAuction.getCurrentPrice(), 1);
    }

    function test_buyTokens() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.init(1000e18);
        address buyer = createUser("buyer");
        
        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);

            uint256 price = dutchAuction.getCurrentPrice();

            uint256 buy = 10e18;
            if (price <= 1000e6 && voteToken.balanceOf(address(dutchAuction)) >= buy) {
                usdc.mint(buyer, buy);
                vm.prank(buyer);
                usdc.approve(address(dutchAuction), buy);

                vm.prank(buyer);
                dutchAuction.buyTokens(buy);
            }
        }

        assertEq(voteToken.balanceOf(address(dutchAuction)), dutchAuction.auctionTokenAmount() - dutchAuction.amountSold());

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        bytes memory customError = abi.encodeWithSignature("AuctionEnded()");
        vm.expectRevert(customError);
        dutchAuction.buyTokens(1);

    }

    function test_withdraw() public {
        mintAndApproveVoteTokens(1000e18);

        dutchAuction.init(1000e18);
        bytes memory customError = abi.encodeWithSignature("AuctionNotEnded()");
        vm.expectRevert(customError);
        dutchAuction.withdraw(voteToken);
                
        for(uint i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);

            vm.expectRevert(customError);
            dutchAuction.withdraw(voteToken);
        }

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 hours);

        dutchAuction.withdraw(voteToken);

        assertEq(voteToken.balanceOf(address(dutchAuction)),0);
    }
}
