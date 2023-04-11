// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EnglishAuction {
    IERC20 public auctionToken;
    IERC20 public paymentToken;
    uint256 public auctionEndTime;
    uint256 public highestBid;
    address public highestBidder;
    uint256 public minimumBidIncrement;
    bool public auctionEnded;
    address public vault;

    event HighestBidIncreased(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    constructor(
        IERC20 _auctionToken,
        IERC20 _paymentToken,
        uint256 _auctionDuration,
        uint256 _minimumBidIncrement,
        address _vault
    ) {
        auctionToken = _auctionToken;
        paymentToken = _paymentToken;
        auctionEndTime = block.timestamp + _auctionDuration;
        minimumBidIncrement = _minimumBidIncrement;
        vault = _vault;
    }

    function bid(uint256 amount) public {
        require(block.timestamp <= auctionEndTime, "Auction already ended");
        require(amount >= highestBid + minimumBidIncrement, "Bid must be higher than the current highest bid");
        require(paymentToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        if (highestBidder != address(0)) {
            require(paymentToken.transfer(highestBidder, highestBid), "Refund failed");
        }

        highestBidder = msg.sender;
        highestBid = amount;
        emit HighestBidIncreased(msg.sender, amount);
    }

    function endAuction() public {
        require(!auctionEnded, "Auction already ended");
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(highestBidder == msg.sender, "Not the highest bidder");

        auctionEnded = true;
        emit AuctionEnded(highestBidder, highestBid);

        // Transfer the auctioned tokens to the highest bidder
        require(auctionToken.transfer(highestBidder, auctionToken.balanceOf(address(this))), "Token transfer failed");

        // Transfer the winning bid amount to the vault
        require(paymentToken.transfer(vault, highestBid), "Token transfer failed");
    }
}