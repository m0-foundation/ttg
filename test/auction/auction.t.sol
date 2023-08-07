// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IAuction } from "../../src/auction/IAuction.sol";

import { Auction } from "../../src/auction/Auction.sol";

import { Clones, ERC20DecimalsMock } from "../ImportedContracts.sol";
import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract AuctionTest is SPOGBaseTest {
    IAuction public auctionImplementation;
    IAuction public auction;

    address fakeVault = createUser("vault");

    ERC20DecimalsMock internal voteToken = new ERC20DecimalsMock("Vote Token", "VOTE", 18);

    function setUp() public override {
        super.setUp();

        uint256 auctionDuration = 30 days;

        auctionImplementation = new Auction();

        auction = IAuction(Clones.cloneDeterministic(address(auctionImplementation), bytes32(0)));

        mintAndApproveVoteTokens(1000e18);

        vm.prank(fakeVault);
        IAuction(auction).initialize(address(voteToken), address(usdc), auctionDuration, 1000e18);
    }

    function mintAndApproveVoteTokens(uint256 amount) internal {
        vm.prank(address(governor));
        voteToken.mint(address(fakeVault), amount);

        vm.prank(fakeVault);
        voteToken.approve(address(auction), amount);
    }

    function test_init() public {
        assertEq(voteToken.balanceOf(address(auction)), 1000e18);
    }

    function test_getCurrentPrice() public {
        assertEq(auction.getCurrentPrice(), usdc.totalSupply() / 1000);

        for (uint256 i = 0; i < 30 * 24; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1 hours);
        }

        assertEq(auction.getCurrentPrice(), 1);
    }

    function test_buyTokens() public {
        address buyer = createUser("buyer");

        for (uint256 i = 0; i < 30 * 24; i++) {
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
        bytes memory customError = abi.encodeWithSignature("AuctionNotEnded()");
        vm.expectRevert(customError);
        auction.withdraw();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30 days - 1 seconds);

        vm.expectRevert(customError);
        auction.withdraw();

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 seconds);

        auction.withdraw();

        assertEq(voteToken.balanceOf(address(auction)), 0);
    }
}
