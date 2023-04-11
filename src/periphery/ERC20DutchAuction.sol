// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DutchAuction {
    IERC20 public auctionToken;
    IERC20 public paymentToken;
    uint256 public auctionDuration;
    uint256 public auctionEndTime;
    uint256 public startPrice;
    uint256 public endPrice;
    uint256 public auctionTokenAmount;
    bool public auctionCompleted;
    address public vault;

    event AuctionCompleted(address indexed winner, uint256 amount, uint256 price);

    constructor(
        IERC20 _auctionToken,
        IERC20 _paymentToken,
        uint256 _auctionDuration,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _auctionTokenAmount,
         address _vault
    ) {
        auctionToken = _auctionToken;
        paymentToken = _paymentToken;
        auctionDuration = _auctionDuration;
        auctionEndTime = block.timestamp + _auctionDuration;
        startPrice = _startPrice;
        endPrice = _endPrice;
        auctionTokenAmount = _auctionTokenAmount;
        vault = _vault;

        require(auctionToken.transferFrom(vault, address(this), auctionTokenAmount), "Token transfer failed");
    }

    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp >= auctionEndTime) {
            return endPrice;
        }

        uint256 timePassed = block.timestamp - (auctionEndTime - auctionDuration);
        uint256 priceDifference = startPrice - endPrice;
        uint256 priceDrop = (priceDifference * timePassed) / auctionDuration;

        return startPrice - priceDrop;
    }

    function buyTokens() public {
        require(!auctionCompleted, "Auction already completed");
        require(block.timestamp <= auctionEndTime, "Auction already ended");

        uint256 currentPrice = getCurrentPrice();
        uint256 amountToPay = auctionTokenAmount * currentPrice;

        auctionCompleted = true;

        // Transfer the auctioned tokens to the highest bidder
        require(auctionToken.transfer(msg.sender, auctionTokenAmount), "Token transfer failed");

        // Transfer the winning bid amount to the vault
        require(paymentToken.transferFrom(msg.sender, vault, amountToPay), "Token transfer failed");

        emit AuctionCompleted(msg.sender, auctionTokenAmount, currentPrice);
    }

    function withdraw() public {
        require(block.timestamp > auctionEndTime, "Auction not yet ended");
        require(!auctionCompleted, "Auction already completed");

        auctionCompleted = true;

        require(auctionToken.transfer(vault, auctionToken.balanceOf(address(this))), "Token transfer failed");
    }
}
