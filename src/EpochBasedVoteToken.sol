// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { PureEpochs } from "./PureEpochs.sol";
import { ERC5805 } from "./ERC5805.sol";
import { ERC20Permit } from "./ERC20Permit.sol";

// TODO: Consider making more external function (like `balanceOf`, and `balanceOfAt`) public.
// TODO: Consider `getPastVotes` for and array of epochs and between start and end epochs.
// TODO: Consider `delegatesAt` for and array of epochs and between start and end epochs.

contract EpochBasedVoteToken is IEpochBasedVoteToken, ERC5805, ERC20Permit {
    struct AmountWindow {
        uint16 startingEpoch;
        uint240 amount;
    }

    struct AccountWindow {
        uint16 startingEpoch;
        address account;
    }

    AmountWindow[] internal _totalSupplies;

    mapping(address account => AmountWindow[] balanceWindows) internal _balances;

    mapping(address account => AccountWindow[] delegateeWindows) internal _delegatees;

    mapping(address delegatee => AmountWindow[] votingPowerWindows) internal _votingPowers;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Permit(name_, symbol_, decimals_) {}

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function balanceOf(address account_) external view virtual returns (uint256 balance_) {
        return _getLatestValue(_balances[account_]);
    }

    function balanceOfAt(address account_, uint256 epoch_) external view virtual returns (uint256 balance_) {
        return _getValueAt(_balances[account_], epoch_);
    }

    function balancesOfAt(
        address account_,
        uint256[] calldata epochs_
    ) external view virtual returns (uint256[] memory balances_) {
        return _getValuesAt(_balances[account_], epochs_);
    }

    function balancesOfBetween(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view virtual returns (uint256[] memory balances_) {
        return _getValuesBetween(_balances[account_], startEpoch_, endEpoch_);
    }

    function clock() external view returns (uint48 clock_) {
        return uint48(PureEpochs.currentEpoch());
    }

    function delegates(address account_) external view returns (address delegatee_) {
        return _getDelegatee(account_);
    }

    function delegatesAt(address account_, uint256 epoch_) external view returns (address delegatee_) {
        return _getDelegateeAt(account_, epoch_);
    }

    function getVotes(address account_) public view virtual returns (uint256 votingPower_) {
        return _getLatestValue(_votingPowers[account_]);
    }

    function getPastVotes(address account_, uint256 epoch_) public view virtual returns (uint256 votingPower_) {
        return _getValueAt(_votingPowers[account_], epoch_);
    }

    function totalSupply() public view virtual returns (uint256 totalSupply_) {
        return _getLatestValue(_totalSupplies);
    }

    function totalSupplyAt(uint256 epoch_) public view virtual returns (uint256 totalSupply_) {
        return _getValueAt(_totalSupplies, epoch_);
    }

    function totalSuppliesAt(uint256[] calldata epochs_) public view virtual returns (uint256[] memory totalSupplies_) {
        return _getValuesAt(_totalSupplies, epochs_);
    }

    function totalSuppliesBetween(
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view virtual returns (uint256[] memory totalSupplies_) {
        return _getValuesBetween(_totalSupplies, startEpoch_, endEpoch_);
    }

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        return "mode=epoch";
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _addBalance(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldAmount_, uint256 newAmount_) {
        return _updateBalance(account_, _add, amount_);
    }

    function _addTotalSupply(uint256 amount_) internal virtual {
        _update(_totalSupplies, _add, amount_);
    }

    function _addVotingPower(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldVotingPower_, uint256 newVotingPower_) {
        return _updateVotingPower(account_, _add, amount_);
    }

    function _delegate(address delegator_, address newDelegatee_) internal virtual override {
        address oldDelegatee_ = _setDelegatee(delegator_, newDelegatee_);
        uint256 votingPower_ = _getLatestValue(_balances[delegator_]);

        if (votingPower_ == 0) return;

        // NOTE: An overridden `_removeVotingPower` may not decrease the voting power as expected.
        (uint256 oldVotingPower_, uint256 newVotingPower_) = _removeVotingPower(oldDelegatee_, votingPower_);
        _addVotingPower(newDelegatee_, oldVotingPower_ - newVotingPower_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual {
        emit Transfer(address(0), recipient_, amount_);

        _addBalance(recipient_, amount_);
        _addTotalSupply(amount_);
        _addVotingPower(_getDelegatee(recipient_), amount_);
    }

    function _removeBalance(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldAmount_, uint256 newAmount_) {
        return _updateBalance(account_, _sub, amount_);
    }

    function _removeVotingPower(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldVotingPower_, uint256 newVotingPower_) {
        return _updateVotingPower(account_, _sub, amount_);
    }

    function _setDelegatee(address delegator_, address delegatee_) internal returns (address oldDelegatee_) {
        // `delegatee_` will be `delegator_` if it was passed in as `address(0)`.
        delegatee_ = _getDefaultIfZero(delegatee_, delegator_);

        // The delegatee that will be written to storage will be `address(0)` if `delegatee_` is `delegator_`.
        address delegateeToWrite_ = _getZeroIfDefault(delegatee_, delegator_);

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        AccountWindow[] storage accountWindows_ = _delegatees[delegator_];

        uint256 length_ = accountWindows_.length;

        // If this will be the first AccountWindow, we can just push it onto the empty array.
        if (length_ == 0) {
            if (delegatee_ == delegator_) revert AlreadyDelegated();

            accountWindows_.push(AccountWindow(uint16(currentEpoch_), delegateeToWrite_));

            return delegator_;
        }

        AccountWindow storage currentAccountWindow_ = _unsafeAccountWindowAccess(accountWindows_, length_ - 1);

        // `oldDelegatee_` will be `delegator_` if it was retrieved as `address(0)`.
        oldDelegatee_ = _getDefaultIfZero(currentAccountWindow_.account, delegator_);

        if (oldDelegatee_ == delegatee_) revert AlreadyDelegated();

        emit DelegateChanged(delegator_, oldDelegatee_, delegatee_);

        if (currentEpoch_ > currentAccountWindow_.startingEpoch) {
            accountWindows_.push(AccountWindow(uint16(currentEpoch_), delegateeToWrite_));
        } else {
            currentAccountWindow_.account = delegateeToWrite_;
        }
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal virtual override {
        if (sender_ == recipient_) revert TransferToSelf();

        emit Transfer(sender_, recipient_, amount_);

        // NOTE: An overridden `_removeBalance` and/or `_removeVotingPower` may not decrease values as expected.
        (uint256 oldAmount_, uint256 newAmount_) = _removeBalance(sender_, amount_);
        (uint256 oldVotingPower_, uint256 newVotingPower_) = _removeVotingPower(
            _getDelegatee(sender_),
            oldAmount_ - newAmount_
        );

        _addBalance(recipient_, oldAmount_ - newAmount_);
        _addVotingPower(_getDelegatee(recipient_), oldVotingPower_ - newVotingPower_);
    }

    function _update(
        AmountWindow[] storage amountWindows_,
        function(uint256, uint256) returns (uint256) operation_,
        uint256 amount_
    ) internal returns (uint256 oldAmount_, uint256 newAmount_) {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 length_ = amountWindows_.length;

        // If this will be the first AmountWindow, we can just push it onto the empty array.
        if (length_ == 0) {
            if (amount_ > type(uint240).max) revert AmountExceedsUint240();

            amountWindows_.push(AmountWindow(uint16(currentEpoch_), uint240(amount_)));

            return (0, amount_);
        }

        AmountWindow storage currentAmountWindow_ = _unsafeAmountWindowAccess(amountWindows_, length_ - 1);

        newAmount_ = operation_(oldAmount_ = currentAmountWindow_.amount, amount_);

        if (newAmount_ > type(uint240).max) revert AmountExceedsUint240();

        if (currentEpoch_ > currentAmountWindow_.startingEpoch) {
            amountWindows_.push(AmountWindow(uint16(currentEpoch_), uint240(newAmount_)));
        } else {
            currentAmountWindow_.amount = uint240(newAmount_);
        }
    }

    function _updateBalance(
        address account_,
        function(uint256, uint256) returns (uint256) operation_,
        uint256 amount_
    ) internal returns (uint256 oldAmount_, uint256 newAmount_) {
        return _update(_balances[account_], operation_, amount_);
    }

    function _updateVotingPower(
        address delegatee_,
        function(uint256, uint256) returns (uint256) operation_,
        uint256 amount_
    ) internal virtual returns (uint256 oldVotingPower_, uint256 newVotingPower_) {
        (oldVotingPower_, newVotingPower_) = _update(_votingPowers[delegatee_], operation_, amount_);

        emit DelegateVotesChanged(delegatee_, oldVotingPower_, newVotingPower_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getLatestAccount(AccountWindow[] storage accountWindows_) internal view returns (address account_) {
        uint256 length_ = accountWindows_.length;

        return length_ == 0 ? address(0) : _unsafeAccountWindowAccess(accountWindows_, length_ - 1).account;
    }

    function _getAccountAt(
        AccountWindow[] storage accountWindows_,
        uint256 epoch_
    ) internal view returns (address account_) {
        uint256 index_ = accountWindows_.length;

        if (index_ == 0) return address(0);

        // Keep going back as long as the epoch is greater or equal to the previous AccountWindow's startingEpoch.
        do {
            AccountWindow storage accountWindow_ = _unsafeAccountWindowAccess(accountWindows_, --index_);

            if (accountWindow_.startingEpoch <= epoch_) return accountWindow_.account;
        } while (index_ > 0);
    }

    function _getDelegatee(address account_) internal view returns (address delegatee_) {
        // The delegatee is the account itself if there are no or were no delegatees.
        return _getDefaultIfZero(_getLatestAccount(_delegatees[account_]), account_);
    }

    function _getDelegateeAt(address account_, uint256 epoch_) internal view returns (address delegatee_) {
        // The delegatee is the account itself if there are no or were no delegatees.
        return _getDefaultIfZero(_getAccountAt(_delegatees[account_], epoch_), account_);
    }

    function _getLatestValue(AmountWindow[] storage amountWindows_) internal view returns (uint256 value_) {
        uint256 length_ = amountWindows_.length;

        return length_ == 0 ? 0 : _unsafeAmountWindowAccess(amountWindows_, length_ - 1).amount;
    }

    function _getValueAt(AmountWindow[] storage amountWindows_, uint256 epoch_) internal view returns (uint256 value_) {
        uint256 index_ = amountWindows_.length;

        if (index_ == 0) return 0;

        // Keep going back as long as the epoch is greater or equal to the previous AmountWindow's startingEpoch.
        do {
            AmountWindow storage amountWindow_ = _unsafeAmountWindowAccess(amountWindows_, --index_);

            if (amountWindow_.startingEpoch <= epoch_) return amountWindow_.amount;
        } while (index_ > 0);
    }

    function _getValuesAt(
        AmountWindow[] storage amountWindows_,
        uint256[] memory epochs_
    ) internal view returns (uint256[] memory values_) {
        uint256 epochsIndex_ = epochs_.length;

        values_ = new uint256[](epochsIndex_);

        uint256 windowIndex_ = amountWindows_.length;

        if (windowIndex_ == 0 || epochsIndex_ == 0) return values_;

        uint256 epoch_ = epochs_[--epochsIndex_];

        // Keep going back as long as the epoch is greater or equal to the previous AmountWindow's startingEpoch.
        do {
            AmountWindow storage amountWindow_ = _unsafeAmountWindowAccess(amountWindows_, --windowIndex_);

            uint256 amountWindowStartingEpoch_ = amountWindow_.startingEpoch;

            // Keep checking if the AmountWindow's startingEpoch is applicable to the current and decrementing epoch.
            while (amountWindowStartingEpoch_ <= epoch_) {
                values_[epochsIndex_] = amountWindow_.amount;

                if (epochsIndex_ == 0) return values_;

                uint256 previousEpoch_ = epochs_[--epochsIndex_];

                if (previousEpoch_ >= epoch_) revert InvalidEpochOrdering();

                epoch_ = previousEpoch_;
            }
        } while (windowIndex_ > 0);
    }

    function _getValuesBetween(
        AmountWindow[] storage amountWindows_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) internal view returns (uint256[] memory values_) {
        uint256 epochsIndex_ = endEpoch_ - startEpoch_ + 1;

        values_ = new uint256[](epochsIndex_);

        uint256 windowIndex_ = amountWindows_.length;

        if (windowIndex_ == 0 || epochsIndex_ == 0) return values_;

        uint256 epoch_ = endEpoch_;

        // Keep going back as long as the epoch is greater or equal to the previous AmountWindow's startingEpoch.
        do {
            AmountWindow storage amountWindow_ = _unsafeAmountWindowAccess(amountWindows_, --windowIndex_);

            uint256 amountWindowStartingEpoch_ = amountWindow_.startingEpoch;

            // Keep checking if the AmountWindow's startingEpoch is applicable to the current and decrementing epoch.
            while (amountWindowStartingEpoch_ <= epoch_) {
                values_[epochsIndex_] = amountWindow_.amount;

                if (epochsIndex_ == 0) return values_;

                --epochsIndex_;
                --epoch_;
            }
        } while (windowIndex_ > 0);
    }

    function _add(uint256 a_, uint256 b_) internal pure returns (uint256 sum_) {
        return a_ + b_;
    }

    function _getDefaultIfZero(address input_, address default_) internal pure returns (address output_) {
        return input_ == address(0) ? default_ : input_;
    }

    function _getZeroIfDefault(address input_, address default_) internal pure returns (address output_) {
        return input_ == default_ ? address(0) : input_;
    }

    function _sub(uint256 a_, uint256 b_) internal pure returns (uint256 difference_) {
        return a_ - b_;
    }

    function _unsafeAmountWindowAccess(
        AmountWindow[] storage amountWindows_,
        uint256 index_
    ) internal pure returns (AmountWindow storage amountWindow_) {
        assembly {
            mstore(0, amountWindows_.slot)
            amountWindow_.slot := add(keccak256(0, 0x20), index_)
        }
    }

    function _unsafeAccountWindowAccess(
        AccountWindow[] storage accountWindows_,
        uint256 index_
    ) internal pure returns (AccountWindow storage accountWindow_) {
        assembly {
            mstore(0, accountWindows_.slot)
            accountWindow_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
