// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";

import { IEpochBasedInflationaryVoteToken } from "./interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

// NOTE: There is no feasible way to emit `Transfer` events for inflationary minting such that external client can
//       index them and track balances and total supply correctly. Specifically, and only for total supply indexing, one
//       can assume that total supply is the sum of all voting powers, thus tracking the deltas of the
//       `DelegateVotesChanged` events will suffice.

/**
 * @title  Extension for an EpochBasedVoteToken token that allows for inflating tokens and voting power.
 * @author M^0 Labs
 */
abstract contract EpochBasedInflationaryVoteToken is IEpochBasedInflationaryVoteToken, EpochBasedVoteToken {
    /* ============ Structs ============ */

    /// @dev A 32-byte struct containing a starting epoch that merely marks that something occurred in this epoch.
    struct VoidSnap {
        uint16 startingEpoch;
    }

    /* ============ Variables ============ */

    /// @inheritdoc IEpochBasedInflationaryVoteToken
    uint16 public constant ONE = 10_000; // 100% in basis points.

    /// @inheritdoc IEpochBasedInflationaryVoteToken
    uint16 public immutable participationInflation; // In basis points.

    /// @dev The participation snaps for each delegatee.
    mapping(address delegatee => VoidSnap[] participationSnaps) internal _participations;

    /* ============ Modifiers ============ */

    modifier notDuringVoteEpoch() {
        _revertIfInVoteEpoch();
        _;
    }

    modifier onlyDuringVoteEpoch() {
        _revertIfNotInVoteEpoch();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new EpochBasedInflationaryVoteToken contract.
     * @param  name_                   The name of the token.
     * @param  symbol_                 The symbol of the token.
     * @param  decimals_               The decimals of the token.
     * @param  participationInflation_ The participation inflation rate used to inflate tokens for participation.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint16 participationInflation_
    ) EpochBasedVoteToken(name_, symbol_, decimals_) {
        if (participationInflation_ > ONE) revert InflationTooHigh();

        participationInflation = participationInflation_;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IEpochBasedInflationaryVoteToken
    function sync(address account_) external {
        _sync(account_);

        emit Sync(account_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IEpochBasedInflationaryVoteToken
    function hasParticipatedAt(address delegatee_, uint256 epoch_) external view returns (bool) {
        return _hasParticipatedAt(delegatee_, UIntMath.safe16(epoch_));
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Delegate voting power from `delegator_` to `newDelegatee_`.
     * @param delegator_    The address of the account delegating voting power.
     * @param newDelegatee_ The address of the account receiving voting power.
     */
    function _delegate(address delegator_, address newDelegatee_) internal virtual override notDuringVoteEpoch {
        _sync(delegator_);
        super._delegate(delegator_, newDelegatee_);
    }

    /**
     * @dev   Allows for the inflation of a delegatee's voting power (and total supply) up to one time per epoch.
     * @param delegatee_ The address of the account being marked as having participated.
     */
    function _markParticipation(address delegatee_) internal onlyDuringVoteEpoch {
        uint16 currentEpoch_ = _clock();

        // Revert if could not update, as it means the delegatee has already participated in this epoch.
        if (!_update(_participations[delegatee_], currentEpoch_)) revert AlreadyParticipated();

        _sync(delegatee_);

        uint240 inflation_ = _getInflation(_getVotes(delegatee_, currentEpoch_));

        // NOTE: Cannot sync here because it would prevent `delegatee_` from getting inflation if their delegatee votes.
        // NOTE: Don't need to sync here because participating has no effect on the balance of `delegatee_`.
        _addTotalSupply(inflation_);
        _addVotingPower(delegatee_, inflation_);
    }

    /**
     * @dev   Mint `amount_` tokens to `recipient_`.
     * @param recipient_ The address of the account to mint tokens to.
     * @param amount_    The amount of tokens to mint.
     */
    function _mint(address recipient_, uint256 amount_) internal override notDuringVoteEpoch {
        _sync(recipient_);
        super._mint(recipient_, amount_);
    }

    /**
     * @dev   Syncs `account_` so that its balance Snap array in storage, reflects their unrealized inflation.
     * @param account_ The address of the account to sync.
     */
    function _sync(address account_) internal virtual {
        // Realized the account's unrealized inflation since its last sync.
        _addBalance(account_, _getUnrealizedInflation(account_, _clock()));
    }

    /**
     * @dev Transfers `amount_` tokens from `sender_` to `recipient_`.
     * @param sender_    The address of the account to transfer tokens from.
     * @param recipient_ The address of the account to transfer tokens to.
     * @param amount_    The amount of tokens to transfer.
     */
    function _transfer(address sender_, address recipient_, uint256 amount_) internal override notDuringVoteEpoch {
        _sync(sender_);

        if (recipient_ != sender_) _sync(recipient_);

        super._transfer(sender_, recipient_, amount_);
    }

    /**
     * @dev    Update a storage VoidSnap array to contain the current epoch as the latest snap.
     * @param  voidSnaps_ The storage pointer to a VoidSnap array to update.
     * @param  epoch_     The epoch to write as the latest element of the VoidSnap array.
     * @return updated_   Whether the VoidSnap array was updated, and thus did not already contain the current epoch.
     */
    function _update(VoidSnap[] storage voidSnaps_, uint16 epoch_) internal returns (bool updated_) {
        uint256 length_ = voidSnaps_.length;

        unchecked {
            // If this will be the first or a new VoidSnap, just push it onto the array.
            if (updated_ = ((length_ == 0) || (epoch_ > _unsafeAccess(voidSnaps_, length_ - 1).startingEpoch))) {
                voidSnaps_.push(VoidSnap(epoch_));
            }
        }
    }

    /* ============ Internal View/Pure Functions ============ */

    /**
     * @dev    Returns the balance of `account_` plus any inflation that in unrealized before `epoch_`.
     * @param  account_ The account to get the balance for.
     * @param  epoch_   The epoch to get the balance at.
     * @return The balance of `account_` plus any inflation that in unrealized before `epoch_`.
     */
    function _getBalance(address account_, uint16 epoch_) internal view virtual override returns (uint240) {
        unchecked {
            return
                UIntMath.bound240(
                    uint256(super._getBalance(account_, epoch_)) + _getUnrealizedInflation(account_, epoch_)
                );
        }
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
    ) internal view virtual returns (uint240) {
        return super._getBalance(account_, epoch_);
    }

    /**
     * @dev    Returns the inflation of `amount` due to participation inflation.
     * @param  amount_ The amount to determine inflation for.
     * @return The inflation of `amount` due to participation inflation.
     */
    function _getInflation(uint240 amount_) internal view returns (uint240) {
        unchecked {
            return uint240((uint256(amount_) * participationInflation) / ONE); // Cannot overflow.
        }
    }

    /**
     * @dev    Returns the epoch of the last sync of `account_` at or before `epoch_`.
     *         Override this function in order to return the "default"/starting epoch if the account has never synced.
     * @param  account_ The account to get the last sync for.
     * @param  epoch_   The epoch to get the last sync at or before.
     * @return The epoch of the last sync of `account_` at or before `epoch_`.
     */
    function _getLastSync(address account_, uint16 epoch_) internal view virtual returns (uint16) {
        if (epoch_ == 0) revert EpochZero();

        AmountSnap[] storage amountSnaps_ = _balances[account_];

        uint256 index_ = amountSnaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // is the most recent to `epoch_`, so return its startingEpoch. If we exhaust the array, then it's 0.
        while (index_ > 0) {
            unchecked {
                uint16 snapStartingEpoch_ = _unsafeAccess(amountSnaps_, --index_).startingEpoch;

                if (snapStartingEpoch_ <= epoch_) return snapStartingEpoch_;
            }
        }

        return 0;
    }

    /**
     * @dev    Returns whether `delegatee_` has participated during the clock value `epoch_`.
     * @param  delegatee_ The account whose participation is being queried.
     * @param  epoch_     The epoch at which to determine participation.
     * @return Whether `delegatee_` has participated during the clock value `epoch_`.
     */
    function _hasParticipatedAt(address delegatee_, uint16 epoch_) internal view returns (bool) {
        if (epoch_ == 0) revert EpochZero();

        VoidSnap[] storage voidSnaps_ = _participations[delegatee_];

        uint256 index_ = voidSnaps_.length; // NOTE: `index_` starts out as length, and would be out of bounds.

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`.
        // If this snap's startingEpoch is equal to `epoch_`, it means the delegatee did participate in `epoch_`.
        // If this startingEpoch is less than `epoch_`, it means the delegatee did not participated in `epoch_`.
        // If we exhaust the array, then the delegatee never participated in any epoch prior to `epoch_`.
        while (index_ > 0) {
            unchecked {
                uint16 snapStartingEpoch_ = _unsafeAccess(voidSnaps_, --index_).startingEpoch;

                if (snapStartingEpoch_ > epoch_) continue;

                return snapStartingEpoch_ == epoch_;
            }
        }

        return false;
    }

    /**
     * @dev    Returns the unrealized inflation for `account_` from their last sync to the epoch before `lastEpoch_`.
     * @param  account_   The account being queried.
     * @param  lastEpoch_ The last epoch at which to determine unrealized inflation, not inclusive.
     * @return inflation_ The total unrealized inflation that has yet to be synced.
     */
    function _getUnrealizedInflation(address account_, uint16 lastEpoch_) internal view returns (uint240 inflation_) {
        // The balance and delegatee the account had at the epoch are the same since the last sync (by definition).
        uint240 balance_ = _getBalanceWithoutUnrealizedInflation(account_, lastEpoch_);

        if (balance_ == 0) return 0; // No inflation if the account had no balance.

        uint256 inflatedBalance_ = balance_;
        address delegatee_ = _getDelegatee(account_, lastEpoch_); // Internal avoids `_revertIfNotPastTimepoint`.

        // NOTE: Starting from the epoch after the latest sync, before `lastEpoch_`.
        // NOTE: If account never synced (i.e. it never interacted with the contract nor received tokens or voting
        //       power), then `epoch_` will start at 0, which can result in a longer loop than needed. Inheriting
        //       contracts should override `_getLastSync` to return the most recent appropriate epoch for such an
        //       account, such as the epoch when the contract was deployed, some bootstrap epoch, etc.
        for (uint16 epoch_ = _getLastSync(account_, lastEpoch_); epoch_ < lastEpoch_; ++epoch_) {
            // Skip non-voting epochs and epochs when the delegatee did not participate.
            if (!_isVotingEpoch(epoch_) || !_hasParticipatedAt(delegatee_, epoch_)) continue;

            unchecked {
                inflatedBalance_ += _getInflation(uint240(inflatedBalance_));

                // Cap inflation to `type(uint240).max`.
                if (inflatedBalance_ >= type(uint240).max) return type(uint240).max - balance_;
            }
        }

        return uint240(inflatedBalance_ - balance_);
    }

    /// @dev Reverts if the current epoch is a voting epoch.
    function _revertIfInVoteEpoch() internal view {
        if (_isVotingEpoch(_clock())) revert VoteEpoch();
    }

    /// @dev Reverts if the current epoch is not a voting epoch.
    function _revertIfNotInVoteEpoch() internal view {
        if (!_isVotingEpoch(_clock())) revert NotVoteEpoch();
    }

    /**
     * @dev    Returns whether the clock value `epoch_` is a voting epoch or not.
     * @param  epoch_ Some clock value.
     * @return Whether the epoch is a voting epoch.
     */
    function _isVotingEpoch(uint16 epoch_) internal pure returns (bool) {
        return epoch_ % 2 == 1; // Voting epochs are odd numbered.
    }

    /**
     * @dev    Returns the VoidSnap in an array at a given index without doing bounds checking.
     * @param  voidSnaps_ The array of VoidSnaps to parse.
     * @param  index_     The index of the VoidSnap to return.
     * @return voidSnap_  The VoidSnap at `index_`.
     */
    function _unsafeAccess(
        VoidSnap[] storage voidSnaps_,
        uint256 index_
    ) internal pure returns (VoidSnap storage voidSnap_) {
        assembly {
            mstore(0, voidSnaps_.slot)
            voidSnap_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
