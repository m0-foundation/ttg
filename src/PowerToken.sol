// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";
import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { EpochBasedInflationaryVoteToken } from "./abstract/EpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";

// NOTE: Balances and voting powers are bootstrapped from the bootstrap token, but delegations are not.
// NOTE: Bootstrapping only works with a bootstrap token aht supports the same PureEpochs as the clock mode.

/**
 * @title An instance of an EpochBasedInflationaryVoteToken delegating control to a Standard Governor, and enabling
 *        auctioning of the unowned inflated supply.
 */
contract PowerToken is IPowerToken, EpochBasedInflationaryVoteToken {
    uint40 internal constant _AUCTION_PERIODS = 100;

    uint240 public constant INITIAL_SUPPLY = 10_000;

    address public immutable bootstrapToken;
    address public immutable standardGovernor;
    address public immutable vault;

    uint16 public immutable bootstrapEpoch;

    uint240 internal immutable _bootstrapSupply;

    uint16 internal _nextCashTokenStartingEpoch;

    address internal _cashToken;
    address internal _nextCashToken;

    uint16 internal _nextTargetSupplyStartingEpoch;

    uint240 internal _targetSupply;
    uint240 internal _nextTargetSupply = INITIAL_SUPPLY;

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

        uint16 bootstrapEpoch_ = bootstrapEpoch = (_clock() - 1);
        uint256 bootstrapSupply_ = IEpochBasedVoteToken(bootstrapToken_).pastTotalSupply(bootstrapEpoch_);

        if (bootstrapSupply_ > type(uint240).max) revert BootstrapSupplyTooLarge();

        _bootstrapSupply = uint240(bootstrapSupply_);

        _addTotalSupply(INITIAL_SUPPLY);
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function buy(
        uint256 minAmount_,
        uint256 maxAmount_,
        address destination_
    ) external returns (uint240 amount_, uint256 cost_) {
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
            uint256(_targetSupply) + (_targetSupply * participationInflation) / ONE
        );

        emit TargetSupplyInflated(targetEpoch_, nextTargetSupply_);
    }

    function markParticipation(address delegatee_) external onlyStandardGovernor {
        _markParticipation(delegatee_);
    }

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

    function amountToAuction() public view returns (uint240 amountToAuction_) {
        if (_isVotingEpoch(_clock())) return 0; // No auction during voting epochs.

        uint240 targetSupply_ = _getTargetSupply();
        uint240 totalSupply_ = _getTotalSupply(_clock());

        unchecked {
            return targetSupply_ > totalSupply_ ? targetSupply_ - totalSupply_ : 0;
        }
    }

    function cashToken() public view returns (address cashToken_) {
        return _clock() >= _nextCashTokenStartingEpoch ? _nextCashToken : _cashToken;
    }

    function getCost(uint256 amount_) public view returns (uint256 cost_) {
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

    function targetSupply() public view returns (uint256 targetSupply_) {
        return _getTargetSupply();
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _bootstrap(address account_) internal {
        if (_lastSyncs[account_].length != 0) return; // Skip if the account already has synced (and thus bootstrapped).

        // NOTE: Don't need add `_getUnrealizedInflation(account_)` here since all callers of `_bootstrap` also call
        //       `_sync`, which will handle that.
        uint240 bootstrapBalance_ = _getBootstrapBalance(account_, bootstrapEpoch);

        if (bootstrapBalance_ == 0) return;

        _addBalance(account_, bootstrapBalance_);
        _addVotingPower(account_, bootstrapBalance_);
    }

    function _delegate(address delegator_, address newDelegatee_) internal override {
        _bootstrap(delegator_);
        _bootstrap(newDelegatee_);

        // NOTE: Need to sync `newDelegatee_` to ensure `_markParticipation` does not overwrite its voting power.
        _sync(newDelegatee_);

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

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

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

    /// @dev This is the portion of the initial supply commensurate with the account's portion of the bootstrap supply.
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

    function _getTotalSupply(uint16 epoch_) internal view override returns (uint240) {
        // For epochs before the bootstrap epoch return the initial supply.
        return epoch_ <= bootstrapEpoch ? INITIAL_SUPPLY : super._getTotalSupply(epoch_);
    }

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

    function _getLastSync(address account_, uint16 epoch_) internal view override returns (uint16) {
        // If there are no LastSync snaps, return the bootstrap epoch.
        return (_lastSyncs[account_].length == 0) ? bootstrapEpoch : super._getLastSync(account_, epoch_);
    }

    function _getTargetSupply() internal view returns (uint240 targetSupply_) {
        return _clock() >= _nextTargetSupplyStartingEpoch ? _nextTargetSupply : _targetSupply;
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
