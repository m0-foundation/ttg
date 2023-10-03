// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IEpochBasedInflationaryVoteToken } from "./interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";
import { PureEpochs } from "./PureEpochs.sol";

// TODO: Use inflation epoch'd inflation indexing instead of participation epochs, to avoid for-loops.

contract EpochBasedInflationaryVoteToken is IEpochBasedInflationaryVoteToken, EpochBasedVoteToken {
    uint256 public constant ONE = 10_000; // 100% in basis points.

    uint256 internal immutable _participationInflation; // In basis points.

    mapping(address account => AmountEpoch[] inflationIndexEpochs) internal _inflationIndices;

    mapping(address delegatee => AmountEpoch[] inflationIndexEpochs) internal _delegateeInflationIndices;

    modifier notDuringVoteEpoch() {
        _revertIfInVoteEpoch();

        _;
    }

    modifier onlyDuringVoteEpoch() {
        _revertIfNotInVoteEpoch();

        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 participationInflation_
    ) EpochBasedVoteToken(name_, symbol_, 0) {
        _participationInflation = participationInflation_;
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function balanceOf(
        address account_
    ) public view virtual override(IERC20, EpochBasedVoteToken) returns (uint256 balance_) {
        balance_ = _getInflatedBalanceOf(account_);
    }

    function balanceOfAt(
        address account_,
        uint256 epoch_
    ) public view virtual override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 balance_) {
        balance_ = _getInflatedBalanceOfAt(account_, epoch_);
    }

    function hasParticipatedAt(address delegatee_, uint256 epoch_) external view returns (bool participated_) {
        participated_ = _getParticipationAt(delegatee_, epoch_);
    }

    function participationInflation() external view returns (uint256 participationInflation_) {
        participationInflation_ = _participationInflation;
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _delegate(address delegator_, address newDelegatee_) internal virtual override notDuringVoteEpoch {
        _sync(delegator_);

        super._delegate(delegator_, newDelegatee_);

        _setInflationIndex(
            _inflationIndices[delegator_],
            _getLatestValue(_delegateeInflationIndices[_getDefaultIfZero(newDelegatee_, delegator_)])
        );
    }

    function _markParticipation(address delegatee_) internal onlyDuringVoteEpoch {
        uint256 inflationIndex_ = (_getOneIfZero(_getLatestValue(_delegateeInflationIndices[delegatee_])) *
            (ONE + _participationInflation)) / ONE;

        if (_setInflationIndex(_delegateeInflationIndices[delegatee_], inflationIndex_)) revert AlreadyParticipated();

        uint256 inflation_ = (_getLatestValue(_votingPowers[delegatee_]) * _participationInflation) / ONE;

        _update(_totalSupplies, _add, inflation_);
        _updateVotingPower(delegatee_, _add, inflation_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual override notDuringVoteEpoch {
        _sync(recipient_);
        super._mint(recipient_, amount_);
    }

    function _sync(address account_) internal {
        uint256 balance_ = _getLatestValue(_balances[account_]);
        address delegatee_ = _getDefaultIfZero(_getLatestAccount(_delegatees[account_]), account_);
        uint256 delegateeInflationIndex_ = _getLatestValue(_delegateeInflationIndices[delegatee_]);

        uint256 inflation_ = _getInflatedBalance(
            balance_,
            _getLatestValue(_inflationIndices[account_]),
            _getOneIfZero(delegateeInflationIndex_)
        ) - balance_;

        _updateBalance(account_, _add, inflation_);
        _setInflationIndex(_inflationIndices[account_], delegateeInflationIndex_);
    }

    function _transfer(
        address sender_,
        address recipient_,
        uint256 amount_
    ) internal virtual override notDuringVoteEpoch {
        _sync(sender_);
        _sync(recipient_);
        super._transfer(sender_, recipient_, amount_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getInflatedBalance(
        uint256 balance_,
        uint256 accountInflationIndex_,
        uint256 delegateeInflationIndex_
    ) internal pure returns (uint256 inflatedBalance_) {
        inflatedBalance_ = (balance_ * _getOneIfZero(delegateeInflationIndex_)) / _getOneIfZero(accountInflationIndex_);
    }

    function _getInflatedBalanceOf(address account_) internal view returns (uint256 inflatedBalance_) {
        uint256 balance_ = _getLatestValue(_balances[account_]);

        if (balance_ == 0) return 0;

        inflatedBalance_ = _getInflatedBalance(
            balance_,
            _getLatestValue(_inflationIndices[account_]),
            _getLatestValue(
                _delegateeInflationIndices[_getDefaultIfZero(_getLatestAccount(_delegatees[account_]), account_)]
            )
        );
    }

    function _getInflatedBalanceOfAt(
        address account_,
        uint256 epoch_
    ) internal view returns (uint256 inflatedBalance_) {
        uint256 balance_ = _getValueAt(_balances[account_], epoch_);

        if (balance_ == 0) return 0;

        inflatedBalance_ = _getInflatedBalance(
            balance_,
            _getValueAt(_inflationIndices[account_], epoch_),
            _getValueAt(
                _delegateeInflationIndices[_getDefaultIfZero(_getAccountAt(_delegatees[account_], epoch_), account_)],
                epoch_
            )
        );
    }

    function _getOneIfZero(uint256 input_) internal pure returns (uint256 output_) {
        output_ = input_ == 0 ? ONE : input_;
    }

    function _getParticipationAt(address delegatee_, uint256 epoch_) internal view returns (bool participated_) {
        AmountEpoch[] storage amountEpochs_ = _delegateeInflationIndices[delegatee_];

        uint256 index_ = amountEpochs_.length;

        if (index_ == 0) return false;

        // Keep going back as long as the epoch is greater or equal to the previous AmountEpoch's startingEpoch.
        do {
            AmountEpoch storage amountEpoch_ = _unsafeAmountEpochAccess(amountEpochs_, --index_);

            uint256 startingEpoch_ = amountEpoch_.startingEpoch;

            if (startingEpoch_ > epoch_) continue;

            return startingEpoch_ == epoch_;
        } while (index_ > 0);
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        isVotingEpoch_ = epoch_ % 2 == 1;
    }

    function _revertIfInVoteEpoch() internal view {
        if (_isVotingEpoch(PureEpochs.currentEpoch())) revert VoteEpoch();
    }

    function _revertIfNotInVoteEpoch() internal view {
        if (!_isVotingEpoch(PureEpochs.currentEpoch())) revert NotVoteEpoch();
    }

    function _setInflationIndex(
        AmountEpoch[] storage amountEpochs_,
        uint256 amount_
    ) internal returns (bool overwritten_) {
        if (amount_ > type(uint240).max) revert AmountExceedsUint240();

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 length_ = amountEpochs_.length;

        // If this will be the first AmountEpoch, we can just push it onto the empty array.
        if (length_ == 0) {
            amountEpochs_.push(AmountEpoch(uint16(currentEpoch_), uint240(amount_)));

            return false;
        }

        AmountEpoch storage currentAmountEpoch_ = _unsafeAmountEpochAccess(amountEpochs_, length_ - 1);

        if (currentEpoch_ == currentAmountEpoch_.startingEpoch) {
            currentAmountEpoch_.amount = uint240(amount_);

            return true;
        }

        amountEpochs_.push(AmountEpoch(uint16(currentEpoch_), uint240(amount_)));

        return false;
    }
}
