// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DutchAuction {
    IERC20 public auctionToken;
    IERC20 public paymentToken;
    uint256 public auctionDuration;
    uint256 public auctionEndTime;
    uint256 public ceilingPrice;
    uint256 public floorPrice;
    address public vault;

    event AuctionPurchase(address indexed buyer, uint256 amount, uint256 price);

    constructor(
        IERC20 _auctionToken,
        IERC20 _paymentToken,
        uint256 _auctionDuration,
        uint256 _ceilingPrice,
        uint256 _floorPrice,
        address _vault
    ) {
        auctionToken = _auctionToken;
        paymentToken = _paymentToken;
        auctionDuration = _auctionDuration;
        auctionEndTime = block.timestamp + _auctionDuration;
        ceilingPrice = _ceilingPrice;
        floorPrice = _floorPrice;
        vault = _vault;
    }

    function depositFromVault(uint256 _auctionTokenAmount) public {
        require(auctionToken.transferFrom(vault, address(this), _auctionTokenAmount), "Token transfer failed");
    }

    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp >= auctionEndTime) {
            return floorPrice;
        }

        uint256 timePassed = block.timestamp - (auctionEndTime - auctionDuration);
        uint256 priceDifference = ceilingPrice - floorPrice;
        uint256 priceDrop = (priceDifference * timePassed) / auctionDuration;

        return ceilingPrice - priceDrop;
    }

    function buyTokens(uint256 amountToPay) public {
        require(auctionToken.balanceOf(address(this)) > 0, "Auction balance is zero");
        require(block.timestamp <= auctionEndTime, "Auction already ended");

        uint256 currentPrice = getCurrentPrice();
        uint256 amountToReceive = amountToPay / currentPrice;

        // Transfer the winning bid amount to the vault
        require(paymentToken.transferFrom(msg.sender, vault, amountToPay), "Token transfer failed");

        // Transfer the auctioned tokens to the highest bidder
        require(auctionToken.transfer(msg.sender, amountToReceive), "Token transfer failed");

        emit AuctionPurchase(msg.sender, amountToReceive, currentPrice);
    }

    function buyAllTokens() public {
        uint256 currentPrice = getCurrentPrice();
        uint256 amountToPay = auctionToken.balanceOf(address(this)) * currentPrice;
        
        buyTokens(amountToPay);
    }

    function withdraw() public {
        require(block.timestamp > auctionEndTime, "Auction not yet ended");
        require(auctionToken.balanceOf(address(this)) > 0, "Auction already completed");

        require(auctionToken.transfer(vault, auctionToken.balanceOf(address(this))), "Token transfer failed");
    }
}
