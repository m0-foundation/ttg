// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";
import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { EpochBasedInflationaryVoteToken } from "./abstract/EpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";

// NOTE: Balances and voting powers are bootstrapped from the bootstrap token, but delegations are not.
// NOTE: Bootstrapping only works with a bootstrap token that supports the same PureEpochs as the clock mode.

/**
 * @title An instance of an EpochBasedInflationaryVoteToken delegating control to a Standard Governor, and enabling
 *        auctioning of the unowned inflated supply.
 */
contract PowerToken is IPowerToken, EpochBasedInflationaryVoteToken {
    /// @dev The number of auction periods in an epoch.
    uint40 internal constant _AUCTION_PERIODS = 100;

    /// @inheritdoc IPowerToken
    uint240 public constant INITIAL_SUPPLY = 10_000;

    /// @inheritdoc IPowerToken
    address public immutable bootstrapToken;

    /// @inheritdoc IPowerToken
    address public immutable standardGovernor;

    /// @inheritdoc IPowerToken
    address public immutable vault;

    /// @inheritdoc IPowerToken
    uint16 public immutable bootstrapEpoch;

    /// @dev The total supply of the bootstrap token at the bootstrap epoch.
    uint240 internal immutable _bootstrapSupply;

    /// @dev The starting epoch of the next cash token.
    uint16 internal _nextCashTokenStartingEpoch;

    /// @dev The address of the cash token required to buy from the token auction.
    address internal _cashToken;

    /// @dev The address of the next cash token.
    address internal _nextCashToken;

    /// @dev The starting epoch of the next target supply.
    uint16 internal _nextTargetSupplyStartingEpoch;

    /// @dev The current target supply of the token.
    uint240 internal _targetSupply;

    /// @dev The next target supply of the token.
    uint240 internal _nextTargetSupply = INITIAL_SUPPLY;

    /// @notice Reverts if the caller is not the Standard Governor.
    modifier onlyStandardGovernor() {
        _revertIfNotStandardGovernor();
        _;
    }

    /**
     * @notice Constructs a new Power Token contract.
     * @param  bootstrapToken_   The address of the token to bootstrap balances and voting powers from.
     * @param  standardGovernor_ The address of the Standard Governor contract to delegate control to.
     * @param  cashToken_        The address of the token to auction the unowned inflated supply for.
     * @param  vault_            The address of the vault to transfer cash tokens to.
     */
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

        uint16 bootstrapEpoch_ = bootstrapEpoch = (_clock() - 1);
        uint256 bootstrapSupply_ = IEpochBasedVoteToken(bootstrapToken_).pastTotalSupply(bootstrapEpoch_);

        if (bootstrapSupply_ > type(uint240).max) revert BootstrapSupplyTooLarge();

        _bootstrapSupply = uint240(bootstrapSupply_);

        _addTotalSupply(INITIAL_SUPPLY);
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IPowerToken
    function buy(
        uint256 minAmount_,
        uint256 maxAmount_,
        address destination_,
        uint16 expiryEpoch_
    ) external returns (uint240 amount_, uint256 cost_) {
        // NOTE: Buy order has an epoch-based expiration logic to avoid user's unfair purchases in subsequent auctions.
        //       Order should be typically valid till the end of current transfer epoch.
        if (_clock() > expiryEpoch_) revert ExpiredBuyOrder();
        if (minAmount_ == 0 || maxAmount_ == 0) revert ZeroPurchaseAmount();

        uint240 amountToAuction_ = amountToAuction();
        uint240 safeMinAmount_ = UIntMath.safe240(minAmount_);
        uint240 safeMaxAmount_ = UIntMath.safe240(maxAmount_);

        amount_ = amountToAuction_ > safeMaxAmount_ ? safeMaxAmount_ : amountToAuction_;

        if (amount_ < safeMinAmount_) revert InsufficientAuctionSupply(amountToAuction_, safeMinAmount_);

        emit Buy(msg.sender, amount_, cost_ = getCost(amount_));

        // NOTE: Not calling `distribute` on vault since anyone can do it, anytime, and this contract should not need to
        //       know how the vault works
        if (!ERC20Helper.transferFrom(cashToken(), msg.sender, vault, cost_)) revert TransferFromFailed();

        _mint(destination_, amount_);
    }

    /// @inheritdoc IPowerToken
    function markNextVotingEpochAsActive() external onlyStandardGovernor {
        // The next voting epoch is the targetEpoch.
        uint16 currentEpoch_ = _clock();
        uint16 targetEpoch_ = currentEpoch_ + (_isVotingEpoch(currentEpoch_) ? 2 : 1);

        // If the current epoch is already on or after the `_nextTargetSupplyStartingEpoch`, then rotate the variables
        // and track the next `_nextTargetSupplyStartingEpoch`, else just overwrite `nextTargetSupply_` only.
        if (currentEpoch_ >= _nextTargetSupplyStartingEpoch) {
            _targetSupply = _nextTargetSupply;
            _nextTargetSupplyStartingEpoch = targetEpoch_;
        }

        // NOTE: Cap the next target supply at `type(uint240).max`.
        uint240 nextTargetSupply_ = _nextTargetSupply = UIntMath.bound240(
            uint256(_targetSupply) + (uint256(_targetSupply) * participationInflation) / ONE
        );

        emit TargetSupplyInflated(targetEpoch_, nextTargetSupply_);
    }

    /// @inheritdoc IPowerToken
    function markParticipation(address delegatee_) external onlyStandardGovernor {
        _markParticipation(delegatee_);
    }

    /// @inheritdoc IPowerToken
    function setNextCashToken(address nextCashToken_) external onlyStandardGovernor {
        if (nextCashToken_ == address(0)) revert InvalidCashTokenAddress();

        // The next epoch is the targetEpoch.
        uint16 currentEpoch_ = _clock();
        uint16 targetEpoch_ = currentEpoch_ + 1;

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

    /// @inheritdoc IPowerToken
    function amountToAuction() public view returns (uint240) {
        if (_isVotingEpoch(_clock())) return 0; // No auction during voting epochs.

        uint240 targetSupply_ = _getTargetSupply();
        uint240 totalSupply_ = _getTotalSupply(_clock());

        unchecked {
            return targetSupply_ > totalSupply_ ? targetSupply_ - totalSupply_ : 0;
        }
    }

    /// @inheritdoc IPowerToken
    function cashToken() public view returns (address) {
        return _clock() >= _nextCashTokenStartingEpoch ? _nextCashToken : _cashToken;
    }

    /// @inheritdoc IPowerToken
    function getCost(uint256 amount_) public view returns (uint256) {
        uint16 currentEpoch_ = _clock();

        uint40 timeRemaining_ = _isVotingEpoch(currentEpoch_)
            ? PureEpochs._EPOCH_PERIOD
            : PureEpochs.timeRemainingInCurrentEpoch();

        uint40 secondsPerPeriod_ = PureEpochs._EPOCH_PERIOD / _AUCTION_PERIODS;
        uint256 leftPoint_ = uint256(1) << (timeRemaining_ / secondsPerPeriod_); // Max is 1 << 100.
        uint40 remainder_ = timeRemaining_ % secondsPerPeriod_;

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
        // NOTE: A good amount of this can be done unchecked, but not every step, so it would look messy.
        return
            _divideUp(
                UIntMath.safe240(amount_) *
                    ((remainder_ * leftPoint_) + ((secondsPerPeriod_ - remainder_) * (leftPoint_ >> 1))),
                uint256(secondsPerPeriod_) * _getTotalSupply(currentEpoch_ - 1)
            );
    }

    /// @inheritdoc IPowerToken
    function targetSupply() public view returns (uint256) {
        return _getTargetSupply();
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @dev   Bootstrap the account's balance and voting power from the bootstrap token.
     * @param account_ The account to bootstrap.
     */
    function _bootstrap(address account_) internal {
        if (_lastSyncs[account_].length != 0) return; // Skip if the account already has synced (and thus bootstrapped).

        // NOTE: Don't need add `_getUnrealizedInflation(account_)` here since all callers of `_bootstrap` also call
        //       `_sync`, which will handle that.
        uint240 bootstrapBalance_ = _getBootstrapBalance(account_, bootstrapEpoch);

        if (bootstrapBalance_ == 0) return;

        _addBalance(account_, bootstrapBalance_);
        _addVotingPower(account_, bootstrapBalance_);
    }

    /**
     * @dev   Delegate voting power from `delegator_` to `newDelegatee_`.
     * @param delegator_    The address of the account delegating voting power.
     * @param newDelegatee_ The address of the account receiving voting power.
     */
    function _delegate(address delegator_, address newDelegatee_) internal override {
        _bootstrap(delegator_);
        if (delegator_ != newDelegatee_) _bootstrap(newDelegatee_);

        // NOTE: Need to sync `newDelegatee_` to ensure `_markParticipation` does not overwrite its voting power.
        _sync(newDelegatee_);

        super._delegate(delegator_, newDelegatee_);
    }

    /**
     * @dev   Allows for the inflation of a delegatee's voting power (and total supply) up to one time per epoch.
     * @param delegatee_ The address of the account being marked as having participated.
     */
    function _markParticipation(address delegatee_) internal override {
        _bootstrap(delegatee_);
        super._markParticipation(delegatee_);
    }

    /**
     * @dev   Mint `amount_` tokens to `recipient_`.
     * @param recipient_ The address of the account to mint tokens to.
     * @param amount_    The amount of tokens to mint.
     */
    function _mint(address recipient_, uint256 amount_) internal override {
        _bootstrap(recipient_);
        super._mint(recipient_, amount_);
    }

    /**
     * @dev   Transfers `amount_` tokens from `sender_` to `recipient_`.
     * @param sender_    The address of the account to transfer tokens from.
     * @param recipient_ The address of the account to transfer tokens to.
     * @param amount_    The amount of tokens to transfer.
     */
    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _bootstrap(sender_);
        if (sender_ != recipient_) _bootstrap(recipient_);

        super._transfer(sender_, recipient_, amount_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    /**
     * @dev    Returns the balance of `account_` plus any inflation that in unrealized before `epoch_`.
     * @param  account_ The account to get the balance for.
     * @param  epoch_   The epoch to get the balance at.
     * @return The balance of `account_` plus any inflation that in unrealized before `epoch_`.
     */
    function _getBalance(address account_, uint16 epoch_) internal view override returns (uint240) {
        // For epochs less than or equal to the bootstrap epoch, return the bootstrap balance at that epoch.
        if (epoch_ <= bootstrapEpoch) return _getBootstrapBalance(account_, epoch_);

        // If no snaps, return the bootstrap balance at the bootstrap epoch and unrealized inflation at the epoch.
        if (_balances[account_].length == 0) {
            unchecked {
                return
                    UIntMath.bound240(
                        uint256(_getBootstrapBalance(account_, bootstrapEpoch)) +
                            _getUnrealizedInflation(account_, epoch_)
                    );
            }
        }

        return super._getBalance(account_, epoch_);
    }

    /**
     * @dev    Returns the balance of `account_` at `epoch_` without any unrealized inflation.
     * @param  account_ The account to get the balance for.
     * @param  epoch_   The epoch to get the balance at.
     * @return The balance of `account_` at `epoch` without any unrealized inflation.
     */
    function _getBalanceWithoutUnrealizedInflation(
        address account_,
        uint16 epoch_
    ) internal view override returns (uint240) {
        // For epochs less than or equal to the bootstrap epoch, return the bootstrap balance at that epoch.
        if (epoch_ <= bootstrapEpoch) return _getBootstrapBalance(account_, epoch_);

        // If no snaps, return the bootstrap balance at the bootstrap epoch.
        if (_balances[account_].length == 0) return _getBootstrapBalance(account_, bootstrapEpoch);

        return super._getBalanceWithoutUnrealizedInflation(account_, epoch_);
    }

    /**
     * @dev    This is the portion of the initial supply commensurate with the account's portion of the bootstrap supply.
     * @param  account_ The account to get the bootstrap balance for.
     * @param  epoch_   The epoch to get the bootstrap balance at.
     * @return The bootstrap balance of `account_` at `epoch_`.
     */
    function _getBootstrapBalance(address account_, uint16 epoch_) internal view returns (uint240) {
        unchecked {
            // NOTE: Can safely cast `pastBalanceOf` since the constructor already establishes that the total supply of
            //       the bootstrap token is less than `type(uint240).max`. Can do math unchecked since
            //       `pastBalanceOf * INITIAL_SUPPLY <= type(uint256).max`.
            return
                (uint240(IEpochBasedVoteToken(bootstrapToken).pastBalanceOf(account_, epoch_)) * INITIAL_SUPPLY) /
                _bootstrapSupply;
        }
    }

    /**
     * @dev    Returns the total supply at `epoch_`.
     * @param  epoch_ The epoch to get the total supply at.
     * @return The total supply at `epoch_`.
     */
    function _getTotalSupply(uint16 epoch_) internal view override returns (uint240) {
        // For epochs before the bootstrap epoch return the initial supply.
        return epoch_ <= bootstrapEpoch ? INITIAL_SUPPLY : super._getTotalSupply(epoch_);
    }

    /**
     * @dev    Returns the amount of votes of `account_` plus any inflation that should be realized at `epoch_`.
     * @param  account_ The account to get the votes for.
     * @param  epoch_   The epoch to get the votes at.
     * @return The balance of votes of `account_` plus any inflation that should be realized at `epoch_`.
     */
    function _getVotes(address account_, uint16 epoch_) internal view override returns (uint240) {
        // For epochs less than or equal to the bootstrap epoch, return the bootstrap balance at that epoch.
        if (epoch_ <= bootstrapEpoch) return _getBootstrapBalance(account_, epoch_);

        // If no snaps, return the bootstrap balance at the bootstrap epoch and unrealized inflation at the epoch.
        if (_votingPowers[account_].length == 0) {
            unchecked {
                return
                    UIntMath.bound240(
                        uint256(_getBootstrapBalance(account_, bootstrapEpoch)) +
                            _getUnrealizedInflation(account_, epoch_)
                    );
            }
        }

        return super._getVotes(account_, epoch_);
    }

    /**
     * @dev    Returns the epoch of the last sync of `account_` at or before `epoch_`.
     * @param  account_ The account to get the last sync for.
     * @param  epoch_   The epoch to get the last sync at or before.
     * @return The epoch of the last sync of `account_` at or before `epoch_`.
     */
    function _getLastSync(address account_, uint16 epoch_) internal view override returns (uint16) {
        // If there are no LastSync snaps, return the bootstrap epoch.
        return (_lastSyncs[account_].length == 0) ? bootstrapEpoch : super._getLastSync(account_, epoch_);
    }

    /// @dev Returns the target supply of the token at the current epoch.
    function _getTargetSupply() internal view returns (uint240 targetSupply_) {
        return _clock() >= _nextTargetSupplyStartingEpoch ? _nextTargetSupply : _targetSupply;
    }

    /// @dev Reverts if the caller is not the Standard Governor.
    function _revertIfNotStandardGovernor() internal view {
        if (msg.sender != standardGovernor) revert NotStandardGovernor();
    }

    /**
     * @dev Helper function to calculate `x` / `y`, rounded up.
     * @dev Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
     */
    function _divideUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        if (y == 0) revert DivisionByZero();

        z = (x * ONE) + y;

        if (z < x) revert DivideUpOverflow();

        unchecked {
            z = (z - 1) / y;
        }
    }
}
