// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC20Extended } from "../../lib/common/src/ERC20Extended.sol";
import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { ERC5805 } from "./ERC5805.sol";

/// @title Extension for an ERC5805 token that uses epochs as its clock mode and delegation via IERC1271.
abstract contract EpochBasedVoteToken is IEpochBasedVoteToken, ERC5805, ERC20Extended {
    struct AccountSnap {
        uint16 startingEpoch;
        address account;
    }

    struct AmountSnap {
        uint16 startingEpoch;
        uint240 amount;
    }

    AmountSnap[] internal _totalSupplies;

    mapping(address account => AmountSnap[] balanceSnaps) internal _balances;

    mapping(address account => AccountSnap[] delegateeSnaps) internal _delegatees;

    mapping(address delegatee => AmountSnap[] votingPowerSnaps) internal _votingPowers;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Extended(name_, symbol_, decimals_) {}

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function delegateBySig(
        address account_,
        address delegatee_,
        uint256 nonce_,
        uint256 expiry_,
        bytes memory signature_
    ) external {
        _revertIfExpired(expiry_);
        _revertIfInvalidSignature(account_, _getDelegationDigest(delegatee_, nonce_, expiry_), signature_);
        _checkAndIncrementNonce(account_, nonce_);
        _delegate(account_, delegatee_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        return "mode=epoch";
    }

    function balanceOf(address account_) external view returns (uint256) {
        return _getBalance(account_, _clock());
    }

    function pastBalanceOf(address account_, uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getBalance(account_, safeEpoch_);
    }

    function clock() external view returns (uint48 clock_) {
        return _clock();
    }

    function delegates(address account_) external view returns (address) {
        return _getDelegatee(account_, _clock());
    }

    function pastDelegates(address account_, uint256 epoch_) external view returns (address) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getDelegatee(account_, safeEpoch_);
    }

    function getVotes(address account_) external view returns (uint256) {
        return _getVotes(account_, _clock());
    }

    function getPastVotes(address account_, uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getVotes(account_, safeEpoch_);
    }

    function totalSupply() external view override returns (uint256) {
        return _getTotalSupply(_clock());
    }

    function pastTotalSupply(uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getTotalSupply(safeEpoch_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _addBalance(address account_, uint240 amount_) internal {
        _updateBalance(account_, _addUnchecked, amount_); // Update balance using `_addUnchecked` operation.
    }

    /// @dev Reverts on overflow by using the `_add` operation.
    function _addTotalSupply(uint240 amount_) internal {
        _update(_totalSupplies, _add, amount_); // Update total supply using `_add` operation.
    }

    function _addVotingPower(address account_, uint240 amount_) internal {
        _updateVotingPower(account_, _addUnchecked, amount_); // Update voting power using `_addUnchecked` operation.
    }

    function _delegate(address delegator_, address newDelegatee_) internal virtual override {
        address oldDelegatee_ = _setDelegatee(delegator_, newDelegatee_);
        uint240 votingPower_ = _getBalance(delegator_, _clock());

        if (votingPower_ == 0) return;

        _removeVotingPower(oldDelegatee_, votingPower_);
        _addVotingPower(newDelegatee_, votingPower_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual {
        emit Transfer(address(0), recipient_, amount_);

        uint240 safeAmount_ = UIntMath.safe240(amount_);

        _addTotalSupply(safeAmount_); // Will revert on overflow.
        _addBalance(recipient_, safeAmount_);
        _addVotingPower(_getDelegatee(recipient_, _clock()), safeAmount_);
    }

    /// @dev Reverts on underflow by using the `_add` operation.
    function _removeBalance(address account_, uint240 amount_) internal {
        _updateBalance(account_, _sub, amount_); // Update balance using `_sub` operation.
    }

    /// @dev Reverts on underflow by using the `_add` operation.
    function _removeVotingPower(address account_, uint240 amount_) internal {
        _updateVotingPower(account_, _sub, amount_); // Update voting power using `_sub` operation.
    }

    function _setDelegatee(address delegator_, address delegatee_) internal returns (address oldDelegatee_) {
        // `delegatee_` will be `delegator_` (the default) if `delegatee_` was passed in as `address(0)`.
        delegatee_ = _getDefaultIfZero(delegatee_, delegator_);

        // The delegatee to write to storage will be `address(0)` if `delegatee_` is `delegator_` (the default).
        address delegateeToWrite_ = _getZeroIfDefault(delegatee_, delegator_);
        uint16 currentEpoch_ = _clock();
        AccountSnap[] storage delegateeSnaps_ = _delegatees[delegator_];
        uint256 length_ = delegateeSnaps_.length;

        // If this will be the first AccountSnap, we can just push it onto the empty array.
        if (length_ == 0) {
            delegateeSnaps_.push(AccountSnap(currentEpoch_, delegateeToWrite_));

            return delegator_; // In this case, delegatee has always been the `delegator_` itself.
        }

        unchecked {
            --length_;
        }

        AccountSnap storage latestDelegateeSnap_ = _unsafeAccess(delegateeSnaps_, length_);

        // `oldDelegatee_` will be `delegator_` (the default) if it was retrieved as `address(0)`.
        oldDelegatee_ = _getDefaultIfZero(latestDelegateeSnap_.account, delegator_);

        emit DelegateChanged(delegator_, oldDelegatee_, delegatee_);

        // If the current epoch is greater than the last AccountSnap's startingEpoch, we can push a new
        // AccountSnap onto the array, else we can just update the last AccountSnap's account.
        if (currentEpoch_ > latestDelegateeSnap_.startingEpoch) {
            delegateeSnaps_.push(AccountSnap(currentEpoch_, delegateeToWrite_));
        } else {
            latestDelegateeSnap_.account = delegateeToWrite_;
        }
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal virtual override {
        emit Transfer(sender_, recipient_, amount_);

        uint240 safeAmount_ = UIntMath.safe240(amount_);
        uint16 currentEpoch_ = _clock();

        _removeBalance(sender_, safeAmount_); // Will revert on underflow.
        _removeVotingPower(_getDelegatee(sender_, currentEpoch_), safeAmount_); // Will revert on underflow.
        _addBalance(recipient_, safeAmount_);
        _addVotingPower(_getDelegatee(recipient_, currentEpoch_), safeAmount_);
    }

    function _update(
        AmountSnap[] storage snaps_,
        function(uint240, uint240) returns (uint240) operation_,
        uint240 amount_
    ) internal returns (uint240 oldAmount_, uint240 newAmount_) {
        uint16 currentEpoch_ = _clock();
        uint256 length_ = snaps_.length;

        // If this will be the first AmountSnap, we can just push it onto the empty array.
        if (length_ == 0) {
            // NOTE: `operation_(0, amount_)` is necessary for almost all operations other than setting or adding.
            snaps_.push(AmountSnap(currentEpoch_, operation_(0, amount_)));

            return (0, amount_); // In this case, the old amount was 0.
        }

        unchecked {
            --length_;
        }

        AmountSnap storage lastAmountSnap_ = _unsafeAccess(snaps_, length_);
        newAmount_ = operation_(oldAmount_ = lastAmountSnap_.amount, amount_);

        // If the current epoch is greater than the last AmountSnap's startingEpoch, we can push a new
        // AmountSnap onto the array, else we can just update the last AmountSnap's amount.
        if (currentEpoch_ > lastAmountSnap_.startingEpoch) {
            snaps_.push(AmountSnap(currentEpoch_, newAmount_));
        } else {
            lastAmountSnap_.amount = newAmount_;
        }
    }

    function _updateBalance(
        address account_,
        function(uint240, uint240) returns (uint240) operation_,
        uint240 amount_
    ) internal {
        _update(_balances[account_], operation_, amount_);
    }

    function _updateVotingPower(
        address delegatee_,
        function(uint240, uint240) returns (uint240) operation_,
        uint240 amount_
    ) internal {
        (uint240 oldAmount_, uint240 newAmount_) = _update(_votingPowers[delegatee_], operation_, amount_);

        emit DelegateVotesChanged(delegatee_, oldAmount_, newAmount_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _add(uint240 a_, uint240 b_) internal pure returns (uint240 sum_) {
        return a_ + b_;
    }

    function _addUnchecked(uint240 a_, uint240 b_) internal pure returns (uint240 sum_) {
        unchecked {
            return a_ + b_;
        }
    }

    function _clock() internal view returns (uint16) {
        return PureEpochs.currentEpoch();
    }

    function _getBalance(address account_, uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_balances[account_], epoch_);
    }

    function _getDefaultIfZero(address input_, address default_) internal pure returns (address) {
        return input_ == address(0) ? default_ : input_;
    }

    /// @dev The delegatee is the account itself (the default) if the retrieved delegatee is address(0).
    function _getDelegatee(address account_, uint16 epoch_) internal view virtual returns (address) {
        AccountSnap[] storage delegateeSnaps_ = _delegatees[account_];

        uint256 index_ = delegateeSnaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // has the account applicable to `epoch_`. If we exhaust the array, then the delegatee is address(0).
        while (index_ > 0) {
            AccountSnap storage accountSnap_ = _unsafeAccess(delegateeSnaps_, --index_);

            if (accountSnap_.startingEpoch <= epoch_) return _getDefaultIfZero(accountSnap_.account, account_);
        }

        return account_;
    }

    function _getTotalSupply(uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_totalSupplies, epoch_);
    }

    function _getValueAt(AmountSnap[] storage snaps_, uint16 epoch_) internal view returns (uint240) {
        uint256 index_ = snaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // has the amount applicable to `epoch_`. If we exhaust the array, then the amount is 0.
        while (index_ > 0) {
            AmountSnap storage amountSnap_ = _unsafeAccess(snaps_, --index_);

            if (amountSnap_.startingEpoch <= epoch_) return amountSnap_.amount;
        }

        return 0;
    }

    function _getVotes(address account_, uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_votingPowers[account_], epoch_);
    }

    function _getZeroIfDefault(address input_, address default_) internal pure returns (address output_) {
        return input_ == default_ ? address(0) : input_;
    }

    function _revertIfNotPastTimepoint(uint16 epoch_) internal view {
        uint16 currentEpoch_ = _clock();

        if (epoch_ >= currentEpoch_) revert NotPastTimepoint(epoch_, currentEpoch_);
    }

    function _sub(uint240 a_, uint240 b_) internal pure returns (uint240 difference_) {
        return a_ - b_;
    }

    function _subUnchecked(uint240 a_, uint240 b_) internal pure returns (uint240 difference_) {
        unchecked {
            return a_ - b_;
        }
    }

    /// @dev Returns the AmountSnap in an array at a given index without doing bounds checking.
    function _unsafeAccess(
        AmountSnap[] storage snaps_,
        uint256 index_
    ) internal pure returns (AmountSnap storage snap_) {
        assembly {
            mstore(0, snaps_.slot)
            snap_.slot := add(keccak256(0, 0x20), index_)
        }
    }

    /// @dev Returns the AccountSnap in an array at a given index without doing bounds checking.
    function _unsafeAccess(
        AccountSnap[] storage snaps_,
        uint256 index_
    ) internal pure returns (AccountSnap storage snap_) {
        assembly {
            mstore(0, snaps_.slot)
            snap_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
