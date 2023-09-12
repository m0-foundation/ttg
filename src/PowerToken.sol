// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IERC20 } from "./interfaces/IERC20.sol";
import { IPowerToken } from "./interfaces/IPowerToken.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { EpochBasedInflationaryVoteToken } from "./EpochBasedInflationaryVoteToken.sol";
import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";
import { PureEpochs } from "./PureEpochs.sol";

// TODO: Track global inflation rather than active epochs.

contract PowerToken is IPowerToken, EpochBasedInflationaryVoteToken {
    uint256 public constant AUCTION_FREE_PERIOD = PureEpochs._EPOCH_PERIOD / 3;
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000;

    address internal immutable _cash;
    address internal immutable _bootstrapToken;
    address internal immutable _treasury;

    uint256 internal immutable _bootstrapEpoch;
    uint256 internal immutable _bootstrapSupply;

    uint256 internal _activeEpochs;
    uint256 internal _auctionSlope;

    mapping(uint256 epoch => bool isActiveEpoch) internal _isActiveEpoch;

    constructor(
        address governor_,
        address cash_,
        address treasury_,
        address bootstrapToken_
    ) EpochBasedInflationaryVoteToken("Power Token", "POWER", ONE / 10, governor_) {
        // TODO: Validation.
        _cash = cash_;
        _treasury = treasury_;

        _bootstrapSupply = IEpochBasedVoteToken(_bootstrapToken = bootstrapToken_).totalSupplyAt(
            _bootstrapEpoch = (PureEpochs.currentEpoch() - 1)
        );
    }

    /******************************************************************************************************************\
     *                                     External/Public Interactive Functions                                      *
    \******************************************************************************************************************/

    function buy(uint256 amount_, address destination_) external {
        uint256 cost_ = getCost(amount_);

        emit Buy(msg.sender, amount_, cost_);

        // TODO: Perhaps `_cash` should come from the governor?
        ERC20Helper.transferFrom(_cash, msg.sender, _treasury, cost_);

        _mint(destination_, amount_);
    }

    // TODO: buyWithPermit via ERC712 inheritance.

    function markEpochActive() external onlGovernor {
        uint256 epoch_ = PureEpochs.currentEpoch();

        emit EpochMarkedActive(epoch_);

        _isActiveEpoch[epoch_] = true;

        ++_activeEpochs;
    }

    /******************************************************************************************************************\
     *                                      External/Public View/Pure Functions                                       *
    \******************************************************************************************************************/

    function activeEpochs() external view returns (uint256 activeEpochs_) {
        activeEpochs_ = _activeEpochs;
    }

    function amountToAuction() public view returns (uint256 amountToAuction_) {
        // TODO: Consider tracking the scaled exponent in storage rather than the active epochs.
        uint256 targetSupply_ = (INITIAL_SUPPLY * _scaledExponent(ONE + _participationInflation, _activeEpochs, ONE)) /
            ONE;

        uint256 totalSupply_ = totalSupply();

        amountToAuction_ = targetSupply_ > totalSupply_ ? targetSupply_ - totalSupply_ : 0;
    }

    function auctionSlope() external view returns (uint256 auctionSlope_) {
        auctionSlope_ = _auctionSlope;
    }

    function balanceOf(
        address account_
    ) public view override(IERC20, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        balance_ = _balances[account_].length == 0
            ? _bootstrapBalanceOfAt(account_, _bootstrapEpoch)
            : super.balanceOf(account_);
    }

    function balanceOfAt(
        address account_,
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        balance_ = _balances[account_].length == 0
            ? _bootstrapBalanceOfAt(account_, epoch_)
            : super.balanceOfAt(account_, epoch_);
    }

    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch_) {
        bootstrapEpoch_ = _bootstrapEpoch;
    }

    function bootstrapToken() external view returns (address bootstrapToken_) {
        bootstrapToken_ = _bootstrapToken;
    }

    function cash() external view returns (address cash_) {
        cash_ = _cash;
    }

    function getCost(uint256 amount_) public view returns (uint256 price_) {
        uint256 bocksRemaining_ = PureEpochs.blocksRemainingInCurrentEpoch() +
            (PureEpochs.currentEpoch() % 2 == 0 ? PureEpochs._EPOCH_PERIOD : 0);

        price_ = bocksRemaining_ > AUCTION_FREE_PERIOD
            ? amount_ * _auctionSlope * (bocksRemaining_ - AUCTION_FREE_PERIOD)
            : 0;
    }

    function isActiveEpoch(uint256 epoch_) external view returns (bool isActiveEpoch_) {
        isActiveEpoch_ = _isActiveEpoch[epoch_];
    }

    function totalSupply() public view override(IERC20, EpochBasedVoteToken) returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplies.length == 0 ? INITIAL_SUPPLY : super.totalSupply();
    }

    function totalSupplyAt(
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplies.length == 0 ? INITIAL_SUPPLY : super.totalSupplyAt(epoch_);
    }

    function treasury() external view returns (address treasury_) {
        treasury_ = _treasury;
    }

    /******************************************************************************************************************\
     *                                          Internal View/Pure Functions                                          *
    \******************************************************************************************************************/

    function _bootstrap(address account_) internal {
        if (_balances[account_].length != 0) return;

        uint256 bootstrapBalance_ = _bootstrapBalanceOfAt(account_, _bootstrapEpoch);

        if (bootstrapBalance_ == 0) return;

        _updateBalance(account_, _add, bootstrapBalance_);
    }

    function _bootstrapBalanceOfAt(address account_, uint256 epoch_) internal view returns (uint256 balance_) {
        balance_ =
            (IEpochBasedVoteToken(_bootstrapToken).balanceOfAt(account_, epoch_) * INITIAL_SUPPLY) /
            _bootstrapSupply;
    }

    function _mint(address recipient_, uint256 amount_) internal override {
        _bootstrap(recipient_);
        super._mint(recipient_, amount_);
    }

    function _scaledExponent(uint256 base_, uint256 exponent_, uint256 one_) internal pure returns (uint256 result_) {
        // If exponent_ is odd, set result_ to base_, else set to one_.
        result_ = exponent_ & 1 != 0 ? base_ : one_;

        // Divide exponent_ by 2 (overwriting itself) and proceed if not zero.
        while ((exponent_ >>= 1) != 0) {
            base_ = (base_ * base_) / one_;

            // If exponent_ is even, go back to top.
            if (exponent_ & 1 == 0) continue;

            // If exponent_ is odd, multiply result_ is multiplied by base_.
            result_ = (result_ * base_) / one_;
        }
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _bootstrap(sender_);
        _bootstrap(recipient_);
        super._transfer(sender_, recipient_, amount_);
    }
}
