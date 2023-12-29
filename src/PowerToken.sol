// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IERC5805 } from "./abstract/interfaces/IERC5805.sol";
import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { EpochBasedInflationaryVoteToken } from "./abstract/EpochBasedInflationaryVoteToken.sol";
import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";

// NOTE: Balances and voting powers are bootstrapped from the bootstrap token, but delegations are not.

/**
 * @title An instance of an EpochBasedInflationaryVoteToken delegating control to a Standard Governor, and enabling
 *        auctioning of the unowned inflated supply.
 */
contract PowerToken is IPowerToken, EpochBasedInflationaryVoteToken {
    uint256 internal constant _AUCTION_PERIODS = 100;

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000;

    address public immutable bootstrapToken;
    address public immutable standardGovernor;
    address public immutable vault;

    uint256 public immutable bootstrapEpoch;

    uint256 internal immutable _bootstrapSupply;

    uint256 internal _nextCashTokenStartingEpoch;

    address internal _cashToken;
    address internal _nextCashToken;

    uint256 internal _nextTargetSupplyStartingEpoch;

    uint256 internal _targetSupply;
    uint256 internal _nextTargetSupply = INITIAL_SUPPLY;

    modifier onlyStandardGovernor() {
        if (msg.sender != standardGovernor) revert NotStandardGovernor();
        _;
    }

    constructor(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_,
        address vault_
    ) EpochBasedInflationaryVoteToken("Power Token", "POWER", 0, ONE / 10) {
        if ((bootstrapToken = bootstrapToken_) == address(0)) revert InvalidBootstrapTokenAddress();
        if ((standardGovernor = standardGovernor_) == address(0)) revert InvalidStandardGovernorAddress();
        if ((_nextCashToken = cashToken_) == address(0)) revert InvalidCashTokenAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();

        uint256 bootstrapEpoch_ = bootstrapEpoch = (clock() - 1);
        _bootstrapSupply = IEpochBasedVoteToken(bootstrapToken_).pastTotalSupply(bootstrapEpoch_);

        _addTotalSupply(INITIAL_SUPPLY);
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function buy(
        uint256 minAmount_,
        uint256 maxAmount_,
        address destination_
    ) external returns (uint256 amount_, uint256 cost_) {
        uint256 amountToAuction_ = amountToAuction();

        amount_ = amountToAuction_ > maxAmount_ ? maxAmount_ : amountToAuction_;

        if (amount_ < minAmount_) revert InsufficientAuctionSupply(amountToAuction_, minAmount_);

        emit Buy(msg.sender, amount_, cost_ = getCost(amount_));

        // NOTE: Not calling `distribute` on vault since anyone can do it, anytime, and this contract should not need to
        //       know how the vault works
        if (!ERC20Helper.transferFrom(cashToken(), msg.sender, vault, cost_)) revert TransferFromFailed();

        _mint(destination_, amount_);
    }

    function markNextVotingEpochAsActive() external onlyStandardGovernor {
        // The next voting epoch is the targetEpoch.
        uint256 currentEpoch_ = clock();
        uint256 targetEpoch_ = currentEpoch_ + (_isVotingEpoch(currentEpoch_) ? 2 : 1);

        // If the current epoch is already on or after the `_nextTargetSupplyStartingEpoch`, then rotate the variables
        // and track the next `_nextTargetSupplyStartingEpoch`, else just overwrite `nextTargetSupply_` only.
        if (currentEpoch_ >= _nextTargetSupplyStartingEpoch) {
            _targetSupply = _nextTargetSupply;
            _nextTargetSupplyStartingEpoch = targetEpoch_;
        }

        uint256 nextTargetSupply_ = _nextTargetSupply = _targetSupply + (_targetSupply * participationInflation) / ONE;

        emit TargetSupplyInflated(targetEpoch_, nextTargetSupply_);
    }

    function markParticipation(address delegatee_) external onlyStandardGovernor {
        _markParticipation(delegatee_);
    }

    function setNextCashToken(address nextCashToken_) external onlyStandardGovernor {
        if (nextCashToken_ == address(0)) revert InvalidCashTokenAddress();

        // The next epoch is the targetEpoch.
        uint256 currentEpoch_ = clock();
        uint256 targetEpoch_ = currentEpoch_ + 1;

        // If the current epoch is already on or after the `_nextCashTokenStartingEpoch`, then rotate the variables
        // and track the next `_nextCashTokenStartingEpoch`, else just overwrite `_nextCashToken` only.
        if (currentEpoch_ >= _nextCashTokenStartingEpoch) {
            _cashToken = _nextCashToken;
            _nextCashTokenStartingEpoch = targetEpoch_;
        }

        _nextCashToken = nextCashToken_;

        emit NextCashTokenSet(targetEpoch_, _nextCashToken);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function amountToAuction() public view returns (uint256 amountToAuction_) {
        if (_isVotingEpoch(clock())) return 0; // No auction during voting epochs.

        uint256 targetSupply_ = targetSupply();
        uint256 totalSupply_ = totalSupply();

        return targetSupply_ > totalSupply_ ? targetSupply_ - totalSupply_ : 0;
    }

    function balanceOf(
        address account_
    ) public view override(IERC20, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        // If the account has no balance snaps, return the bootstrap balance.
        return
            _balances[account_].length == 0
                ? _bootstrapBalanceOfAt(account_, bootstrapEpoch)
                : super.balanceOf(account_);
    }

    function pastBalanceOf(
        address account_,
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        // For epochs before the bootstrap epoch, return the bootstrap balance at that epoch.
        if (epoch_ <= bootstrapEpoch) return _bootstrapBalanceOfAt(account_, epoch_);

        // If no balance snaps, return the bootstrap balance at the bootstrap epoch.
        if (_balances[account_].length == 0) return _bootstrapBalanceOfAt(account_, bootstrapEpoch);

        return super.pastBalanceOf(account_, epoch_);
    }

    function cashToken() public view returns (address cashToken_) {
        return clock() >= _nextCashTokenStartingEpoch ? _nextCashToken : _cashToken;
    }

    function getCost(uint256 amount_) public view returns (uint256 cost_) {
        uint256 currentEpoch_ = clock();

        uint256 timeRemaining_ = _isVotingEpoch(currentEpoch_)
            ? PureEpochs._EPOCH_PERIOD
            : PureEpochs.timeRemainingInCurrentEpoch();

        uint256 secondsPerPeriod_ = PureEpochs._EPOCH_PERIOD / _AUCTION_PERIODS;
        uint256 leftPoint_ = 1 << (timeRemaining_ / secondsPerPeriod_);
        uint256 remainder_ = timeRemaining_ % secondsPerPeriod_;

        /**
         * @dev Auction curve:
         *        - During every auction period (1/100th of an epoch) the price starts at some "leftPoint" and decreases
         *          linearly, with time, to some "rightPoint" (which is half of that "leftPoint"). This is done by
         *          computing the weighted average between the "leftPoint" and "rightPoint" for the time remaining in
         *          the auction period.
         *        - For the next next auction period, the new "leftPoint" is half of the previous period's "leftPoint"
         *          (which also equals the previous period's "rightPoint").
         *        - Combined, this results in the price decreasing by half every auction period at a macro level, but
         *          decreasing linearly at a micro-level during each period, without any jumps.
         *      Relative price computation:
         *        - Since the parameters of this auction are fixed forever (there are no mutable auction parameters and
         *          this is not an upgradeable contract), and the token supply is expected to increase relatively
         *          quickly and consistently, the result would be that the price Y for some Z% of the total supply would
         *          occur earlier and earlier in the auction.
         *        - Instead, the desired behavior is that after X seconds into the auction, there will be a price Y for
         *          some Z% of the total supply. In other words, it will always cost 572,662,306,133 cash tokens to buy
         *          1% of the previous epoch's total supply with 5 days left in the auction period.
         *        - To achieve this, the price is instead computed per basis point of the last epoch's total supply.
         */
        return
            _divideUp(
                (ONE * amount_ * ((remainder_ * leftPoint_) + ((secondsPerPeriod_ - remainder_) * (leftPoint_ >> 1)))),
                (secondsPerPeriod_ * pastTotalSupply(currentEpoch_ - 1))
            );
    }

    function getVotes(
        address account_
    ) public view override(IERC5805, EpochBasedVoteToken) returns (uint256 votingPower_) {
        // If the account has no voting power snaps, return the bootstrap voting power.
        return
            _votingPowers[account_].length == 0
                ? _bootstrapBalanceOfAt(account_, bootstrapEpoch)
                : super.getVotes(account_);
    }

    function getPastVotes(
        address account_,
        uint256 epoch_
    ) public view override(IERC5805, EpochBasedVoteToken) returns (uint256 votingPower_) {
        // For epochs before the bootstrap epoch, return the bootstrap balance at that epoch.
        if (epoch_ <= bootstrapEpoch) return _bootstrapBalanceOfAt(account_, epoch_);

        // If no balance snaps, return the bootstrap balance at the bootstrap epoch.
        if (_votingPowers[account_].length == 0) return _bootstrapBalanceOfAt(account_, bootstrapEpoch);

        return super.getPastVotes(account_, epoch_);
    }

    function targetSupply() public view returns (uint256 targetSupply_) {
        return clock() >= _nextTargetSupplyStartingEpoch ? _nextTargetSupply : _targetSupply;
    }

    function pastTotalSupply(
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 totalSupply_) {
        // For epochs before the bootstrap epoch return the initial supply.
        return epoch_ <= bootstrapEpoch ? INITIAL_SUPPLY : super.pastTotalSupply(epoch_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _bootstrap(address account_) internal {
        if (_balances[account_].length != 0) return; // Skip if the account already has balance snaps.

        uint256 bootstrapBalance_ = _bootstrapBalanceOfAt(account_, bootstrapEpoch);

        // TODO: Consider `_addBalance` and `_addVotingPower` anyway, to prevent a future `_bootstrapBalanceOfAt` query.
        if (bootstrapBalance_ == 0) return;

        _addBalance(account_, bootstrapBalance_);
        _addVotingPower(account_, bootstrapBalance_);
    }

    /// @dev This is the portion of the initial supply commensurate with the account's portion of the bootstrap supply.
    function _bootstrapBalanceOfAt(address account_, uint256 epoch_) internal view returns (uint256 balance_) {
        return
            (IEpochBasedVoteToken(bootstrapToken).pastBalanceOf(account_, epoch_) * INITIAL_SUPPLY) / _bootstrapSupply;
    }

    function _delegate(address delegator_, address newDelegatee_) internal override {
        _bootstrap(delegator_);
        _bootstrap(newDelegatee_);
        super._delegate(delegator_, newDelegatee_);
    }

    function _markParticipation(address delegatee_) internal override {
        _bootstrap(delegatee_);
        super._markParticipation(delegatee_);
    }

    function _mint(address recipient_, uint256 amount_) internal override {
        _bootstrap(recipient_);
        super._mint(recipient_, amount_);
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _bootstrap(sender_);
        _bootstrap(recipient_);
        super._transfer(sender_, recipient_, amount_);
    }

    /**
     * @notice Helper function to calculate `x` / `y`, rounded up.
     * @dev    Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
     */
    function _divideUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        unchecked {
            z -= 1;
        }
        z /= y;
    }
}
