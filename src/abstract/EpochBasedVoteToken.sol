// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { ERC20Extended } from "../../lib/common/src/ERC20Extended.sol";
import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IERC5805 } from "./interfaces/IERC5805.sol";
import { IERC6372 } from "./interfaces/IERC6372.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";

import { ERC5805 } from "./ERC5805.sol";

/// @title Extension for an ERC5805 token that uses epochs as its clock mode and delegation via IERC1271.
abstract contract EpochBasedVoteToken is IEpochBasedVoteToken, ERC5805, ERC20Extended {
    /// @dev A 32-byte struct containing a starting epoch and an address that is valid until the next AccountSnap.
    struct AccountSnap {
        uint16 startingEpoch;
        address account;
    }

    /// @dev A 32-byte struct containing a starting epoch and an amount that is valid until the next AmountSnap.
    struct AmountSnap {
        uint16 startingEpoch;
        uint240 amount;
    }

    /// @dev Store the total supply per epoch.
    AmountSnap[] internal _totalSupplies;

    /// @dev Store the balance per epoch per account.
    mapping(address account => AmountSnap[] balanceSnaps) internal _balances;

    /// @dev Store the delegatee per epoch per account.
    mapping(address account => AccountSnap[] delegateeSnaps) internal _delegatees;

    /// @dev Store the voting power per epoch per delegatee.
    mapping(address delegatee => AmountSnap[] votingPowerSnaps) internal _votingPowers;

    /**
     * @notice Constructs a new EpochBasedVoteToken contract.
     * @param  name_     The name of the token.
     * @param  symbol_   The symbol of the token.
     * @param  decimals_ The decimals of the token.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20Extended(name_, symbol_, decimals_) {}

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IEpochBasedVoteToken
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

    /// @inheritdoc IERC20
    function balanceOf(address account_) external view returns (uint256) {
        return _getBalance(account_, _clock());
    }

    /// @inheritdoc IEpochBasedVoteToken
    function getDelegationDigest(address delegatee_, uint256 nonce_, uint256 expiry_) external view returns (bytes32) {
        return _getDelegationDigest(delegatee_, nonce_, expiry_);
    }

    /// @inheritdoc IEpochBasedVoteToken
    function pastBalanceOf(address account_, uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getBalance(account_, safeEpoch_);
    }

    /// @inheritdoc IERC6372
    function clock() external view returns (uint48 clock_) {
        return _clock();
    }

    /// @inheritdoc IERC5805
    function delegates(address account_) external view returns (address) {
        return _getDelegatee(account_, _clock());
    }

    /// @inheritdoc IEpochBasedVoteToken
    function pastDelegates(address account_, uint256 epoch_) external view returns (address) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getDelegatee(account_, safeEpoch_);
    }

    /// @inheritdoc IERC5805
    function getVotes(address account_) external view returns (uint256) {
        return _getVotes(account_, _clock());
    }

    /// @inheritdoc IERC5805
    function getPastVotes(address account_, uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getVotes(account_, safeEpoch_);
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) {
        return _getTotalSupply(_clock());
    }

    /// @inheritdoc IEpochBasedVoteToken
    function pastTotalSupply(uint256 epoch_) external view returns (uint256) {
        uint16 safeEpoch_ = UIntMath.safe16(epoch_);

        _revertIfNotPastTimepoint(safeEpoch_); // Per EIP-5805, should revert if `epoch_` is not in the past.

        return _getTotalSupply(safeEpoch_);
    }

    /// @inheritdoc IERC6372
    function CLOCK_MODE() external pure returns (string memory clockMode_) {
        return "mode=epoch";
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    /**
     * @dev   Add `amount_` to the balance of `account_`, using unchecked math.
     * @param account_ The address of the account to add the balance to.
     * @param amount_  The amount to add to the balance.
     */
    function _addBalance(address account_, uint240 amount_) internal {
        _updateBalance(account_, _addUnchecked, amount_); // Update balance using `_addUnchecked` operation.
    }

    /**
     * @dev   Add `amount_` to the total supply, using checked math.
     * @param amount_ The amount to add to the total supply.
     */
    function _addTotalSupply(uint240 amount_) internal {
        _update(_totalSupplies, _add, amount_); // Update total supply using `_add` operation.
    }

    /**
     * @dev   Add `amount_` to the voting power of `account_`, using unchecked math.
     * @param account_ The address of the account to add the voting power to.
     * @param amount_  The amount to add to the voting power.
     */
    function _addVotingPower(address account_, uint240 amount_) internal {
        _updateVotingPower(account_, _addUnchecked, amount_); // Update voting power using `_addUnchecked` operation.
    }

    /**
     * @dev   Set a new delegatee for `delegator_`.
     * @param delegator_    The address of the account delegating voting power.
     * @param newDelegatee_ The address of the account receiving voting power.
     */
    function _delegate(address delegator_, address newDelegatee_) internal virtual override {
        address oldDelegatee_ = _setDelegatee(delegator_, newDelegatee_);
        uint240 votingPower_ = _getBalance(delegator_, _clock());

        if (votingPower_ == 0) return;

        _removeVotingPower(oldDelegatee_, votingPower_);
        _addVotingPower(_getDefaultIfZero(newDelegatee_, delegator_), votingPower_);
    }

    /**
     * @dev   Mint `amount_` tokens to `recipient_`.
     * @param recipient_ The address of the account to mint tokens to.
     * @param amount_    The amount of tokens to mint.
     */
    function _mint(address recipient_, uint256 amount_) internal virtual {
        emit Transfer(address(0), recipient_, amount_);

        uint240 safeAmount_ = UIntMath.safe240(amount_);

        _addTotalSupply(safeAmount_); // Will revert on overflow.
        _addBalance(recipient_, safeAmount_);
        _addVotingPower(_getDelegatee(recipient_, _clock()), safeAmount_);
    }

    /**
     * @dev   Subtract `amount_` from the balance of `account_`, using checked math.
     * @param account_ The address of the account to subtract the balance from.
     * @param amount_  The amount to subtract from the balance.
     */
    function _removeBalance(address account_, uint240 amount_) internal {
        _updateBalance(account_, _sub, amount_); // Update balance using `_sub` operation.
    }

    /**
     * @dev   Subtract `amount_` of voting power from the balance of `account_`, using checked math.
     * @param account_ The address of the account to subtract the voting power from.
     * @param amount_  The amount of voting power to subtract.
     */
    function _removeVotingPower(address account_, uint240 amount_) internal {
        _updateVotingPower(account_, _sub, amount_); // Update voting power using `_sub` operation.
    }

    /**
     * @dev    Set a new delegatee for `delegator_`.
     * @param  delegator_    The address of the account delegating voting power.
     * @param  delegatee_    The address of the account receiving voting power.
     * @return oldDelegatee_ The address of the previous delegatee of `delegator_`.
     */
    function _setDelegatee(address delegator_, address delegatee_) internal returns (address oldDelegatee_) {
        // `delegatee_` will be `delegator_` (the default) if `delegatee_` was passed in as `address(0)`.
        delegatee_ = _getDefaultIfZero(delegatee_, delegator_);

        uint16 currentEpoch_ = _clock();
        AccountSnap[] storage delegateeSnaps_ = _delegatees[delegator_];
        uint256 length_ = delegateeSnaps_.length;

        // If this will be the first AccountSnap, we can just push it onto the empty array.
        if (length_ == 0) {
            delegateeSnaps_.push(AccountSnap(currentEpoch_, delegatee_));

            emit DelegateChanged(delegator_, delegator_, delegatee_);

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
            delegateeSnaps_.push(AccountSnap(currentEpoch_, delegatee_));
        } else {
            latestDelegateeSnap_.account = delegatee_;
        }
    }

    /**
     * @dev   Transfer `amount_` tokens from `sender_` to `recipient_`.
     * @param sender_    The address of the account to transfer tokens from.
     * @param recipient_ The address of the account to transfer tokens to.
     * @param amount_    The amount of tokens to transfer.
     */
    function _transfer(address sender_, address recipient_, uint256 amount_) internal virtual override {
        emit Transfer(sender_, recipient_, amount_);

        uint240 safeAmount_ = UIntMath.safe240(amount_);
        uint16 currentEpoch_ = _clock();

        _removeBalance(sender_, safeAmount_); // Will revert on underflow.
        _removeVotingPower(_getDelegatee(sender_, currentEpoch_), safeAmount_); // Will revert on underflow.
        _addBalance(recipient_, safeAmount_);
        _addVotingPower(_getDelegatee(recipient_, currentEpoch_), safeAmount_);
    }

    /**
     * @dev    Update a storage AmountSnap by `amount_` given `operation_`.
     * @param  amountSnaps_ The storage pointer to an AmountSnap array to update.
     * @param  operation_   The operation to perform on the old and new amounts.
     * @param  amount_      The amount to update the Snap by.
     * @return oldAmount_   The previous latest amount of the Snap array.
     * @return newAmount_   The new latest amount of the Snap array.
     */
    function _update(
        AmountSnap[] storage amountSnaps_,
        function(uint240, uint240) returns (uint240) operation_,
        uint240 amount_
    ) internal returns (uint240 oldAmount_, uint240 newAmount_) {
        uint16 currentEpoch_ = _clock();
        uint256 length_ = amountSnaps_.length;

        // If this will be the first AmountSnap, we can just push it onto the empty array.
        if (length_ == 0) {
            // NOTE: `operation_(0, amount_)` is necessary for almost all operations other than setting or adding.
            amountSnaps_.push(AmountSnap(currentEpoch_, operation_(0, amount_)));

            return (0, amount_); // In this case, the old amount was 0.
        }

        unchecked {
            --length_;
        }

        AmountSnap storage lastAmountSnap_ = _unsafeAccess(amountSnaps_, length_);
        newAmount_ = operation_(oldAmount_ = lastAmountSnap_.amount, amount_);

        // If the current epoch is greater than the last AmountSnap's startingEpoch, we can push a new
        // AmountSnap onto the array, else we can just update the last AmountSnap's amount.
        if (currentEpoch_ > lastAmountSnap_.startingEpoch) {
            amountSnaps_.push(AmountSnap(currentEpoch_, newAmount_));
        } else {
            lastAmountSnap_.amount = newAmount_;
        }
    }

    /**
     * @dev   Update the balance of `account_` by `amount_` given `operation_`.
     * @param account_   The address of the account to update the balance of.
     * @param operation_ The operation to perform on the old and new amounts.
     * @param amount_    The amount to update the balance by.
     */
    function _updateBalance(
        address account_,
        function(uint240, uint240) returns (uint240) operation_,
        uint240 amount_
    ) internal {
        _update(_balances[account_], operation_, amount_);
    }

    /**
     * @dev   Update the voting power of `delegatee_` by `amount_` given `operation_`.
     * @param delegatee_ The address of the account to update the voting power of.
     * @param operation_ The operation to perform on the old and new amounts.
     * @param amount_    The amount to update the voting power by.
     */
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

    /**
     * @notice Returns the current timepoint according to the mode the contract is operating on.
     * @return Current timepoint.
     */
    function _clock() internal view returns (uint16) {
        return PureEpochs.currentEpoch();
    }

    /**
     * @dev    Get the balance of `account_` at `epoch_`.
     * @param  account_ The address of the account to get the balance of.
     * @param  epoch_   The epoch to get the balance at.
     * @return The balance of `account_` at `epoch_`.
     */
    function _getBalance(address account_, uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_balances[account_], epoch_);
    }

    /**
     * @dev    Get the delegatee of `account_` at `epoch_`.
     * @dev    The delegatee is the account itself (the default) if the retrieved delegatee is address(0).
     * @param  account_ The address of the account to get the delegatee of.
     * @param  epoch_   The epoch to get the delegatee at.
     * @return The delegatee of `account_` at `epoch_`.
     */
    function _getDelegatee(address account_, uint256 epoch_) internal view virtual returns (address) {
        if (epoch_ == 0) revert EpochZero();

        AccountSnap[] storage delegateeSnaps_ = _delegatees[account_];

        uint256 index_ = delegateeSnaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // has the account applicable to `epoch_`. If we exhaust the array, then the delegatee is an account itself.
        while (index_ > 0) {
            AccountSnap storage accountSnap_ = _unsafeAccess(delegateeSnaps_, --index_);

            if (accountSnap_.startingEpoch <= epoch_) return _getDefaultIfZero(accountSnap_.account, account_);
        }

        return account_;
    }

    /**
     * @dev    Get the total supply at `epoch_`.
     * @param  epoch_ The epoch to get the total supply at.
     * @return The total supply at `epoch_`.
     */
    function _getTotalSupply(uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_totalSupplies, epoch_);
    }

    /**
     * @dev    Get the value of an AmountSnap array at a given epoch.
     * @param  amountSnaps_ The array of AmountSnaps to get the value of.
     * @param  epoch_       The epoch to get the value at.
     * @return The value of the AmountSnap array at `epoch_`.
     */
    function _getValueAt(AmountSnap[] storage amountSnaps_, uint16 epoch_) internal view returns (uint240) {
        if (epoch_ == 0) revert EpochZero();

        uint256 index_ = amountSnaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // has the amount applicable to `epoch_`. If we exhaust the array, then the amount is 0.
        while (index_ > 0) {
            AmountSnap storage amountSnap_ = _unsafeAccess(amountSnaps_, --index_);

            if (amountSnap_.startingEpoch <= epoch_) return amountSnap_.amount;
        }

        return 0;
    }

    /**
     * @dev    The votes of `account_` at `epoch_`.
     * @param  account_ The address of the account to get the votes of.
     * @param  epoch_   The epoch to get the votes at.
     * @return The votes of `account_` at `epoch_`.
     */
    function _getVotes(address account_, uint16 epoch_) internal view virtual returns (uint240) {
        return _getValueAt(_votingPowers[account_], epoch_);
    }

    /**
     * @dev   Revert if `epoch_` is not in the past.
     * @param epoch_ The epoch to check.
     */
    function _revertIfNotPastTimepoint(uint16 epoch_) internal view {
        uint16 currentEpoch_ = _clock();

        if (epoch_ >= currentEpoch_) revert NotPastTimepoint(epoch_, currentEpoch_);
    }

    /**
     * @dev    Add `b_` to `a_`, using checked math.
     * @param  a_ The amount to add to.
     * @param  b_ The amount to add.
     * @return The sum of `a_` and `b_`.
     */
    function _add(uint240 a_, uint240 b_) internal pure returns (uint240) {
        return a_ + b_;
    }

    /**
     * @dev    Add `b_` to `a_`, using unchecked math.
     * @param  a_ The amount to add to.
     * @param  b_ The amount to add.
     * @return The sum of `a_` and `b_`.
     */
    function _addUnchecked(uint240 a_, uint240 b_) internal pure returns (uint240) {
        unchecked {
            return a_ + b_;
        }
    }

    /**
     * @dev    Return `default_` if `input_` is equal to address(0), else return `input_`.
     * @param  input_   The input address.
     * @param  default_ The default address.
     * @return The input address if not equal to the zero address, else the default address.
     */
    function _getDefaultIfZero(address input_, address default_) internal pure returns (address) {
        return input_ == address(0) ? default_ : input_;
    }

    /**
     * @dev    Subtract `b_` from `a_`, using checked math.
     * @param  a_ The amount to subtract from.
     * @param  b_ The amount to subtract.
     * @return The difference of `a_` and `b_`.
     */
    function _sub(uint240 a_, uint240 b_) internal pure returns (uint240) {
        return a_ - b_;
    }

    /**
     * @dev    Returns the AmountSnap in an array at a given index without doing bounds checking.
     * @param  amountSnaps_ The array of AmountSnaps to parse.
     * @param  index_       The index of the AmountSnap to return.
     * @return amountSnap_  The AmountSnap at `index_`.
     */
    function _unsafeAccess(
        AmountSnap[] storage amountSnaps_,
        uint256 index_
    ) internal pure returns (AmountSnap storage amountSnap_) {
        assembly {
            mstore(0, amountSnaps_.slot)
            amountSnap_.slot := add(keccak256(0, 0x20), index_)
        }
    }

    /**
     * @dev    Returns the AccountSnap in an array at a given index without doing bounds checking.
     * @param  accountSnaps_ The array of AccountSnaps to parse.
     * @param  index_        The index of the AccountSnap to return.
     * @return accountSnap_  The AccountSnap at `index_`.
     */
    function _unsafeAccess(
        AccountSnap[] storage accountSnaps_,
        uint256 index_
    ) internal pure returns (AccountSnap storage accountSnap_) {
        assembly {
            mstore(0, accountSnaps_.slot)
            accountSnap_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
