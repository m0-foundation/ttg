// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC20, IERC20Metadata } from "../ImportedInterfaces.sol";
import { IAuction } from "./IAuction.sol";

import { Initializable, SafeERC20 } from "../ImportedContracts.sol";

/// @title Auction
/// @notice A contract for conducting a Dutch auction of ERC20 tokens without a price oracle
contract Auction is IAuction, Initializable {
    using SafeERC20 for IERC20;

    error AlreadyInitialized();
    error AuctionBalanceInsufficient();
    error AuctionEnded();
    error AuctionNotEnded();
    error CallerIsNotVault();

    // TODO: Many of these can be immutable.

    address public auctionToken;
    address public paymentToken;
    address public vault;

    uint256 public amountSold;
    uint256 public auctionDuration;
    uint256 public auctionEndTime;
    uint256 public auctionTokenAmount;
    uint256 public ceilingPrice;
    uint256 public floorPrice;
    uint256 public lastBuyPrice;

    bool private _initialized;

    uint256 private constant _CURVE_STEPS = 20;

    modifier onlyVault() {
        if (msg.sender != vault) revert CallerIsNotVault();

        _;
    }

    /// @dev disable constructor for implementation contract. See Vault
    constructor() {
        _disableInitializers();
    }

    // TODO: Not sure why this is needed instead of just a larger constructor. Will revisit.
    /// @notice Initializes the auction contract
    /// @param auctionToken_ The address of the ERC20 token being auctioned
    /// @param paymentToken_ The address of the ERC20 token used as payment
    /// @param auctionDuration_ The duration of the auction in seconds
    /// @param auctionTokenAmount_ The amount of tokens to be auctioned
    function initialize(
        address auctionToken_,
        address paymentToken_,
        uint256 auctionDuration_,
        uint256 auctionTokenAmount_
    ) public initializer {
        auctionToken = auctionToken_;
        paymentToken = paymentToken_;
        auctionDuration = auctionDuration_;
        auctionEndTime = block.timestamp + auctionDuration_;
        ceilingPrice = IERC20(paymentToken).totalSupply();
        floorPrice = 1;
        vault = msg.sender;

        if (_initialized) revert AlreadyInitialized();

        _initialized = true;

        IERC20(auctionToken).safeTransferFrom(msg.sender, address(this), auctionTokenAmount_);

        auctionTokenAmount = auctionTokenAmount_;

        // Order of operations unclear here.
        ceilingPrice =
            IERC20(paymentToken).totalSupply() /
            (auctionTokenAmount / 10 ** IERC20Metadata(auctionToken).decimals());
    }

    /// @notice Returns the current price of the auction
    /// @return The current price per token in payment tokens
    function getCurrentPrice() public view returns (uint256) {
        if (auctionTokenAmount - amountSold == 0) return lastBuyPrice;

        if (block.timestamp >= auctionEndTime) return floorPrice;

        uint256 timePassed = block.timestamp - (auctionEndTime - auctionDuration);
        uint256 priceDifference = ceilingPrice - floorPrice;
        uint256 percentSold = (1e18 * amountSold) / auctionTokenAmount;
        uint256 percentComplete = (1e18 * timePassed) / auctionDuration;
        uint256 percentIncomplete = 1e18 - percentComplete;

        uint256 priceDrop = (((priceDifference * percentComplete) / 1e18) * (1e18 - percentSold)) / 1e18;

        uint256 price = ceilingPrice - priceDrop;

        for (uint256 i; i < _CURVE_STEPS; ++i) {
            price = (price * percentIncomplete) / 1e18;
        }

        return price;
    }

    /// @notice Returns the current price of the auction
    /// @param amountToBuy The amount of tokens to buy
    function buyTokens(uint256 amountToBuy) public {
        if (block.timestamp > auctionEndTime) revert AuctionEnded();

        uint256 currentPrice = getCurrentPrice();
        uint256 amountToPay = (amountToBuy * currentPrice) / 10 ** IERC20Metadata(auctionToken).decimals();

        if (auctionTokenAmount - amountSold < amountToBuy) revert AuctionBalanceInsufficient();

        amountSold = amountSold + amountToBuy;

        // Transfer the winning bid amount to the vault
        IERC20(paymentToken).safeTransferFrom(msg.sender, vault, amountToPay);

        // Transfer the auctioned tokens to the highest bidder
        IERC20(auctionToken).safeTransfer(msg.sender, amountToBuy);

        lastBuyPrice = currentPrice;

        emit AuctionPurchase(msg.sender, amountToBuy, currentPrice);
    }

    /// @notice Withdraws the unsold auction tokens
    function withdraw() public {
        if (block.timestamp < auctionEndTime) revert AuctionNotEnded();

        uint256 balance = IERC20(auctionToken).balanceOf(address(this));

        IERC20(auctionToken).safeTransfer(msg.sender, balance);

        emit AuctionWithdrawal(msg.sender, balance);
    }
}
