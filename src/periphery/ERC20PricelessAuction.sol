// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";

/// @title ERC20PricelessAuction
/// @notice A contract for conducting a Dutch auction of ERC20 tokens without a price oracle
contract ERC20PricelessAuction is IERC20PricelessAuction, Initializable {
    using SafeERC20 for IERC20;

    error AlreadyInitialized();
    error AuctionEnded();
    error AuctionNotEnded();
    error AuctionBalanceInsufficient();

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

    bool initialized;

    uint256 CURVE_STEPS = 20;

    modifier onlyVault() {
        require(msg.sender == vault, "ERC20PricelessAuction: Only vault");

        _;
    }

    /// @dev disable constructor for implementation contract. See Vault
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the auction contract
    /// @param _auctionToken The address of the ERC20 token being auctioned
    /// @param _paymentToken The address of the ERC20 token used as payment
    /// @param _auctionDuration The duration of the auction in seconds
    /// @param _vault The address where the payment tokens will be sent
    /// @param _auctionTokenAmount The amount of tokens to be auctioned
    function initialize(
        address _auctionToken,
        address _paymentToken,
        uint256 _auctionDuration,
        address _vault,
        uint256 _auctionTokenAmount
    ) public initializer {
        auctionToken = _auctionToken;
        paymentToken = _paymentToken;
        auctionDuration = _auctionDuration;
        auctionEndTime = block.timestamp + _auctionDuration;
        ceilingPrice = IERC20(paymentToken).totalSupply();
        floorPrice = 1;
        vault = _vault;
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        IERC20(auctionToken).safeTransferFrom(vault, address(this), _auctionTokenAmount);
        auctionTokenAmount = _auctionTokenAmount;
        ceilingPrice =
            IERC20(paymentToken).totalSupply() / (auctionTokenAmount / 10 ** IERC20Metadata(auctionToken).decimals());
    }

    /// @notice Returns the current price of the auction
    /// @return The current price per token in payment tokens
    function getCurrentPrice() public view returns (uint256) {
        if (auctionTokenAmount - amountSold == 0) {
            return lastBuyPrice;
        }

        if (block.timestamp >= auctionEndTime) {
            return floorPrice;
        }

        uint256 timePassed = block.timestamp - (auctionEndTime - auctionDuration);
        uint256 priceDifference = ceilingPrice - floorPrice;
        uint256 percentSold = 1e18 * amountSold / auctionTokenAmount;
        uint256 percentComplete = 1e18 * timePassed / auctionDuration;
        uint256 percentIncomplete = 1e18 - percentComplete;

        uint256 priceDrop = (priceDifference * percentComplete / 1e18) * (1e18 - percentSold) / 1e18;

        uint256 price = ceilingPrice - priceDrop;

        uint256 i;
        for (i; i < CURVE_STEPS;) {
            price = price * percentIncomplete / 1e18;
            unchecked {
                ++i;
            }
        }

        return price;
    }

    /// @notice Returns the current price of the auction
    /// @param amountToBuy The amount of tokens to buy
    function buyTokens(uint256 amountToBuy) public {
        if (block.timestamp > auctionEndTime) {
            revert AuctionEnded();
        }

        uint256 currentPrice = getCurrentPrice();
        uint256 amountToPay = amountToBuy * currentPrice / 10 ** IERC20Metadata(auctionToken).decimals();

        if (auctionTokenAmount - amountSold < amountToBuy) {
            revert AuctionBalanceInsufficient();
        }

        unchecked {
            amountSold = amountSold + amountToBuy;
        }

        // Transfer the winning bid amount to the vault
        IERC20(paymentToken).safeTransferFrom(msg.sender, vault, amountToPay);

        // Transfer the auctioned tokens to the highest bidder
        IERC20(auctionToken).safeTransfer(msg.sender, amountToBuy);

        lastBuyPrice = currentPrice;

        emit AuctionPurchase(msg.sender, amountToBuy, currentPrice);
    }

    /// @notice Withdraws the unsold auction tokens
    function withdraw() public {
        if (block.timestamp < auctionEndTime) {
            revert AuctionNotEnded();
        }

        uint256 balance = IERC20(auctionToken).balanceOf(address(this));

        IERC20(auctionToken).safeTransfer(msg.sender, balance);

        emit AuctionWithdrawal(msg.sender, balance);
    }
}
