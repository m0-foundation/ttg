// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { PureEpochs } from "./PureEpochs.sol";
import { ERC5805 } from "./ERC5805.sol";
import { ERC20Permit } from "./ERC20Permit.sol";
import { ERC712 } from "./ERC712.sol";

// TODO: Consider making more external function (like `balanceOf`, and `balanceOfAt`) public.
// TODO: Consider `getPastVotes` for and array of epochs and between start and end epochs.
// TODO: Consider `delegatesAt` for and array of epochs and between start and end epochs.

contract EpochBasedVoteToken is IEpochBasedVoteToken, ERC5805, ERC20Permit {
    struct AmountEpoch {
        uint16 startingEpoch;
        uint240 amount;
    }

    struct AccountEpoch {
        uint16 startingEpoch;
        address account;
    }

    AmountEpoch[] internal _totalSupplies;

    mapping(address account => AmountEpoch[] balanceEpochs) internal _balances;

    mapping(address account => AccountEpoch[] delegateeEpochs) internal _delegatees;

    mapping(address delegatee => AmountEpoch[] votingPowerEpochs) internal _votingPowers;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20Permit(symbol_, decimals_) ERC712(name_) {}

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function balanceOf(address account_) external view virtual returns (uint256 balance_) {
        balance_ = _getLatestValue(_balances[account_]);
    }

    function balanceOfAt(address account_, uint256 epoch_) external view virtual returns (uint256 balance_) {
        balance_ = _getValueAt(_balances[account_], epoch_);
    }

    function balancesOfAt(
        address account_,
        uint256[] calldata epochs_
    ) external view virtual returns (uint256[] memory balances_) {
        balances_ = _getValuesAt(_balances[account_], epochs_);
    }

    function balancesOfBetween(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view virtual returns (uint256[] memory balances_) {
        balances_ = _getValuesAt(_balances[account_], new uint256[](endEpoch_ - startEpoch_ + 1));
    }

    function clock() external view returns (uint48 clock_) {
        clock_ = uint48(PureEpochs.currentEpoch());
    }

    function delegates(address account_) external view returns (address delegatee_) {
        delegatee_ = _getDelegatee(account_);
    }

    function delegatesAt(address account_, uint256 epoch_) external view returns (address delegatee_) {
        delegatee_ = _getDelegateeAt(account_, epoch_);
    }

    function getVotes(address account_) public view virtual returns (uint256 votingPower_) {
        votingPower_ = _getLatestValue(_votingPowers[account_]);
    }

    function getPastVotes(address account_, uint256 epoch_) public view virtual returns (uint256 votingPower_) {
        votingPower_ = _getValueAt(_votingPowers[account_], epoch_);
    }

    function totalSupply() public view virtual returns (uint256 totalSupply_) {
        totalSupply_ = _getLatestValue(_totalSupplies);
    }

    function totalSupplyAt(uint256 epoch_) public view virtual returns (uint256 totalSupply_) {
        totalSupply_ = _getValueAt(_totalSupplies, epoch_);
    }

    function totalSuppliesAt(uint256[] calldata epochs_) public view virtual returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = _getValuesAt(_totalSupplies, epochs_);
    }

    function totalSuppliesBetween(
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view virtual returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = _getValuesAt(_totalSupplies, new uint256[](endEpoch_ - startEpoch_ + 1));
    }

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        clockMode_ = "mode=epoch";
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _addBalance(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldAmount_, uint256 newAmount_) {
        (oldAmount_, newAmount_) = _updateBalance(account_, _add, amount_);
    }

    function _addTotalSupply(uint256 amount_) internal virtual {
        _update(_totalSupplies, _add, amount_);
    }

    function _addVotingPower(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldVotingPower_, uint256 newVotingPower_) {
        (oldVotingPower_, newVotingPower_) = _updateVotingPower(account_, _add, amount_);
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
        (oldAmount_, newAmount_) = _updateBalance(account_, _sub, amount_);
    }

    function _removeVotingPower(
        address account_,
        uint256 amount_
    ) internal virtual returns (uint256 oldVotingPower_, uint256 newVotingPower_) {
        (oldVotingPower_, newVotingPower_) = _updateVotingPower(account_, _sub, amount_);
    }

    function _setDelegatee(address delegator_, address delegatee_) internal returns (address oldDelegatee_) {
        // `delegatee_` will be `delegator_` if it was passed in as `address(0)`.
        delegatee_ = _getDefaultIfZero(delegatee_, delegator_);

        // The delegatee that will be written to storage will be `address(0)` if `delegatee_` is `delegator_`.
        address delegateeToWrite_ = _getZeroIfDefault(delegatee_, delegator_);

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        AccountEpoch[] storage accountEpochs_ = _delegatees[delegator_];

        uint256 length_ = accountEpochs_.length;

        // If this will be the first AccountEpoch, we can just push it onto the empty array.
        if (length_ == 0) {
            if (delegatee_ == delegator_) revert AlreadyDelegated();

            accountEpochs_.push(AccountEpoch(uint16(currentEpoch_), delegateeToWrite_));

            return delegator_;
        }

        AccountEpoch storage currentAccountEpoch_ = _unsafeAccountEpochAccess(accountEpochs_, length_ - 1);

        // `oldDelegatee_` will be `delegator_` if it was retrieved as `address(0)`.
        oldDelegatee_ = _getDefaultIfZero(currentAccountEpoch_.account, delegator_);

        if (oldDelegatee_ == delegatee_) revert AlreadyDelegated();

        emit DelegateChanged(delegator_, oldDelegatee_, delegatee_);

        if (currentEpoch_ > currentAccountEpoch_.startingEpoch) {
            accountEpochs_.push(AccountEpoch(uint16(currentEpoch_), delegateeToWrite_));
        } else {
            currentAccountEpoch_.account = delegateeToWrite_;
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
        AmountEpoch[] storage amountEpochs_,
        function(uint256, uint256) returns (uint256) operation_,
        uint256 amount_
    ) internal returns (uint256 oldAmount_, uint256 newAmount_) {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 length_ = amountEpochs_.length;

        // If this will be the first AmountEpoch, we can just push it onto the empty array.
        if (length_ == 0) {
            if (amount_ > type(uint240).max) revert AmountExceedsUint240();

            amountEpochs_.push(AmountEpoch(uint16(currentEpoch_), uint240(amount_)));

            return (0, amount_);
        }

        AmountEpoch storage currentAmountEpoch_ = _unsafeAmountEpochAccess(amountEpochs_, length_ - 1);

        newAmount_ = operation_(oldAmount_ = currentAmountEpoch_.amount, amount_);

        if (newAmount_ > type(uint240).max) revert AmountExceedsUint240();

        if (currentEpoch_ > currentAmountEpoch_.startingEpoch) {
            amountEpochs_.push(AmountEpoch(uint16(currentEpoch_), uint240(newAmount_)));
        } else {
            currentAmountEpoch_.amount = uint240(newAmount_);
        }
    }

    function _updateBalance(
        address account_,
        function(uint256, uint256) returns (uint256) operation_,
        uint256 amount_
    ) internal returns (uint256 oldAmount_, uint256 newAmount_) {
        (oldAmount_, newAmount_) = _update(_balances[account_], operation_, amount_);
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

    function _getLatestAccount(AccountEpoch[] storage accountEpochs_) internal view returns (address account_) {
        uint256 length_ = accountEpochs_.length;

        account_ = length_ == 0 ? address(0) : _unsafeAccountEpochAccess(accountEpochs_, length_ - 1).account;
    }

    function _getAccountAt(
        AccountEpoch[] storage accountEpochs_,
        uint256 epoch_
    ) internal view returns (address account_) {
        uint256 index_ = accountEpochs_.length;

        if (index_ == 0) return address(0);

        // Keep going back as long as the epoch is greater or equal to the previous AccountEpoch's startingEpoch.
        do {
            AccountEpoch storage accountEpoch_ = _unsafeAccountEpochAccess(accountEpochs_, --index_);

            if (accountEpoch_.startingEpoch <= epoch_) return accountEpoch_.account;
        } while (index_ > 0);
    }

    function _getDelegatee(address account_) internal view returns (address delegatee_) {
        // The delegatee is the account itself if there are no or were no delegatees.
        delegatee_ = _getDefaultIfZero(_getLatestAccount(_delegatees[account_]), account_);
    }

    function _getDelegateeAt(address account_, uint256 epoch_) internal view returns (address delegatee_) {
        // The delegatee is the account itself if there are no or were no delegatees.
        delegatee_ = _getDefaultIfZero(_getAccountAt(_delegatees[account_], epoch_), account_);
    }

    function _getLatestValue(AmountEpoch[] storage amountEpochs_) internal view returns (uint256 value_) {
        uint256 length_ = amountEpochs_.length;

        value_ = length_ == 0 ? 0 : _unsafeAmountEpochAccess(amountEpochs_, length_ - 1).amount;
    }

    function _getValueAt(AmountEpoch[] storage amountEpochs_, uint256 epoch_) internal view returns (uint256 value_) {
        uint256 index_ = amountEpochs_.length;

        if (index_ == 0) return 0;

        // Keep going back as long as the epoch is greater or equal to the previous AmountEpoch's startingEpoch.
        do {
            AmountEpoch storage amountEpoch_ = _unsafeAmountEpochAccess(amountEpochs_, --index_);

            if (amountEpoch_.startingEpoch <= epoch_) return amountEpoch_.amount;
        } while (index_ > 0);
    }

    function _getValuesAt(
        AmountEpoch[] storage amountEpochs_,
        uint256[] memory epochs_
    ) internal view returns (uint256[] memory values_) {
        values_ = new uint256[](epochs_.length);

        uint256 index_ = amountEpochs_.length;
        uint256 epochsIndex_ = epochs_.length;

        if (index_ == 0 || epochsIndex_ == 0) return values_;

        uint256 epoch_ = epochs_[--epochsIndex_];

        // Keep going back as long as the epoch is greater or equal to the previous AmountEpoch's startingEpoch.
        do {
            AmountEpoch storage amountEpoch_ = _unsafeAmountEpochAccess(amountEpochs_, --index_);

            uint256 startingEpoch_ = amountEpoch_.startingEpoch;

            // Keep checking if the AmountEpoch's startingEpoch is applicable to the current and decrementing epoch.
            while (startingEpoch_ <= epoch_) {
                values_[epochsIndex_] = amountEpoch_.amount;

                if (epochsIndex_ == 0) return values_;

                uint256 previousEpoch_ = epochs_[--epochsIndex_];

                if (previousEpoch_ >= epoch_) revert InvalidEpochOrdering();

                epoch_ = previousEpoch_;
            }
        } while (index_ > 0);
    }

    function _add(uint256 a_, uint256 b_) internal pure returns (uint256 c_) {
        c_ = a_ + b_;
    }

    function _getDefaultIfZero(address input_, address default_) internal pure returns (address output_) {
        output_ = input_ == address(0) ? default_ : input_;
    }

    function _getZeroIfDefault(address input_, address default_) internal pure returns (address output_) {
        output_ = input_ == default_ ? address(0) : input_;
    }

    function _sub(uint256 a_, uint256 b_) internal pure returns (uint256 c_) {
        c_ = a_ - b_;
    }

    function _unsafeAmountEpochAccess(
        AmountEpoch[] storage amountEpochs_,
        uint256 index_
    ) internal pure returns (AmountEpoch storage amountEpoch_) {
        assembly {
            mstore(0, amountEpochs_.slot)
            amountEpoch_.slot := add(keccak256(0, 0x20), index_)
        }
    }

    function _unsafeAccountEpochAccess(
        AccountEpoch[] storage accountEpochs_,
        uint256 index_
    ) internal pure returns (AccountEpoch storage accountEpoch_) {
        assembly {
            mstore(0, accountEpochs_.slot)
            accountEpoch_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
