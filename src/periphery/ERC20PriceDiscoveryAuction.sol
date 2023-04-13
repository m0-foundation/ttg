// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";

contract PriceDiscoveryAuction {
    IERC20Metadata public auctionToken;
    IERC20Metadata public paymentToken;
    uint256 public auctionDuration;
    uint256 public auctionEndTime;
    uint256 public ceilingPrice;
    uint256 public floorPrice;
    address public vault;
    uint256 public auctionTokenAmount;
    uint256 public amountSold;

    event AuctionPurchase(address indexed buyer, uint256 amount, uint256 price);

    constructor(
        IERC20Metadata _auctionToken,
        IERC20Metadata _paymentToken,
        uint256 _auctionDuration,
        address _vault
    ) {
        auctionToken = _auctionToken;
        paymentToken = _paymentToken;
        auctionDuration = _auctionDuration;
        auctionEndTime = block.timestamp + _auctionDuration;
        ceilingPrice = paymentToken.totalSupply();
        floorPrice = 1;
        vault = _vault;
    }

    function depositFromVault(uint256 _auctionTokenAmount) public {
        require(auctionToken.transferFrom(vault, address(this), _auctionTokenAmount), "Token transfer failed");
        auctionTokenAmount+=_auctionTokenAmount;
        ceilingPrice = paymentToken.totalSupply();
    }

    function getCurrentPrice() public view returns (uint256) {
        if (block.timestamp >= auctionEndTime) {
            return floorPrice;
        }

        uint256 timePassed = block.timestamp - (auctionEndTime - auctionDuration);
        uint256 priceDifference = ceilingPrice - floorPrice;
        uint256 percentSold = 1e18 * amountSold / auctionTokenAmount;
        uint256 percentComplete = 1e18 * timePassed / auctionDuration;
        uint256 percentIncomplete = 1e18 - percentComplete;

        uint256 priceDrop = priceDifference * percentComplete / 1e18;

        uint256 price = (ceilingPrice - priceDrop * (1e18 - percentSold) / 1e18) * percentIncomplete / 1e18 * percentIncomplete / 1e18 * percentIncomplete / 1e18 * percentIncomplete / 1e18 * percentIncomplete / 1e18;

        if (price < floorPrice) {
            price = floorPrice;
        }
        return price;
    }

    function buyTokens(uint256 amountToBuy) public {
        require(block.timestamp <= auctionEndTime, "Auction already ended");

        uint256 currentPrice = getCurrentPrice();
        uint256 amountToPay = amountToBuy * currentPrice / 10 ** auctionToken.decimals();

        console.log('amount to pay', amountToPay);

        require(auctionToken.balanceOf(address(this)) > amountToBuy, "Auction balance is insufficient");

        // Transfer the winning bid amount to the vault
        require(paymentToken.transferFrom(msg.sender, vault, amountToPay), "Token transfer failed");

        // Transfer the auctioned tokens to the highest bidder
        require(auctionToken.transfer(msg.sender, amountToBuy), "Token transfer failed");

        amountSold+=amountToBuy;

        emit AuctionPurchase(msg.sender, amountToBuy, currentPrice);
    }

    function withdraw() public {
        require(block.timestamp > auctionEndTime, "Auction not yet ended");
        require(auctionToken.balanceOf(address(this)) > 0, "Auction already completed");

        require(auctionToken.transfer(vault, auctionToken.balanceOf(address(this))), "Token transfer failed");
    }
}
