// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedInflationaryVoteToken } from "./interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

// TODO: Test sync before or after actions.

// NOTE: There is no feasible way to emit `Transfer` events for inflationary minting such that external client can
//       index them and track balances and total supply correctly. Specifically,a nd only for total supply indexing, one
//       can assume that total supply is the sum of all voting powers, thus tracking the deltas of the
//       `DelegateVotesChanged` events will suffice.

/// @title Extension for an EpochBasedVoteToken token that allows for inflating tokens and voting power.
abstract contract EpochBasedInflationaryVoteToken is IEpochBasedInflationaryVoteToken, EpochBasedVoteToken {
    struct VoidSnap {
        uint16 startingEpoch;
    }

    uint256 public constant ONE = 10_000; // 100% in basis points.

    uint256 public immutable participationInflation; // In basis points.

    mapping(address delegatee => VoidSnap[] participationSnaps) internal _participations;

    mapping(address account => VoidSnap[] lastSyncSnaps) internal _lastSyncs;

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
        uint8 decimals_,
        uint256 participationInflation_
    ) EpochBasedVoteToken(name_, symbol_, decimals_) {
        participationInflation = participationInflation_;
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function hasParticipatedAt(address delegatee_, uint256 epoch_) external view returns (bool) {
        return _hasParticipatedAt(delegatee_, epoch_);
    }

    /******************************************************************************************************************\
    |                                          Internal Interactive Functions                                          |
    \******************************************************************************************************************/

    function _delegate(address delegator_, address newDelegatee_) internal virtual override notDuringVoteEpoch {
        _sync(delegator_);
        super._delegate(delegator_, newDelegatee_);
    }

    /// @dev Allows for the inflation of a delegatee's voting power (and total supply) up to one time per epoch.
    function _markParticipation(address delegatee_) internal virtual onlyDuringVoteEpoch {
        if (!_update(_participations[delegatee_])) revert AlreadyParticipated(); // Revert if could not update.

        uint256 inflation_ = _getInflation(_getVotes(delegatee_, clock()));

        // NOTE: Cannot sync here because it would prevent `delegatee_` from getting inflation if their delegatee votes.
        // NOTE: Don't need to sync here because participating has no effect on the balance of `delegatee_`.
        _addTotalSupply(inflation_);
        _addVotingPower(delegatee_, inflation_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual override notDuringVoteEpoch {
        _sync(recipient_);
        super._mint(recipient_, amount_);
    }

    function _sync(address account_) internal {
        // Realized the account's unrealized inflation since the its last sync, and update its last sync.
        _addBalance(account_, _getUnrealizedInflation(account_, clock()));
        _update(_lastSyncs[account_]);
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

    function _update(VoidSnap[] storage voidSnaps_) internal returns (bool updated_) {
        uint16 currentEpoch_ = uint16(clock());
        uint256 length_ = voidSnaps_.length;

        // If this will be the first or a new VoidSnap, just push it onto the array.
        if (updated_ = ((length_ == 0) || (currentEpoch_ > _unsafeAccess(voidSnaps_, length_ - 1).startingEpoch))) {
            voidSnaps_.push(VoidSnap(currentEpoch_));
        }
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getBalance(address account_, uint256 epoch_) internal view virtual override returns (uint256) {
        return super._getBalance(account_, epoch_) + _getUnrealizedInflation(account_, epoch_);
    }

    function _getBalanceWithoutUnrealizedInflation(
        address account_,
        uint256 epoch_
    ) internal view virtual returns (uint256) {
        return super._getBalance(account_, epoch_);
    }

    function _getInflation(uint256 amount_) internal view returns (uint256) {
        return (amount_ * participationInflation) / ONE;
    }

    /// @dev Override this function in order to return the "default"/starting epoch if the account has never synced.
    function _getLastSync(address account_, uint256 epoch_) internal view virtual returns (uint256) {
        uint256 index_ = _lastSyncs[account_].length;

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // is the most recent to `epoch_`, so return its startingEpoch. If we exhaust the array, then it's 0.
        while (index_ > 0) {
            VoidSnap storage voidSnap_ = _unsafeAccess(_lastSyncs[account_], --index_);
            uint256 snapStartingEpoch_ = voidSnap_.startingEpoch;

            if (snapStartingEpoch_ <= epoch_) return snapStartingEpoch_;
        }
    }

    function _hasParticipatedAt(address delegatee_, uint256 epoch_) internal view returns (bool) {
        VoidSnap[] storage voidSnaps_ = _participations[delegatee_];

        uint256 index_ = voidSnaps_.length;

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`.
        // If this snap's startingEpoch is equal to `epoch_`, it means the delegatee did participate in `epoch_`.
        // If this startingEpoch is less than `epoch_`, it means the delegatee did not participated in `epoch_`.
        // If we exhaust the array, then the delegatee never participated in any epoch prior to `epoch_`.
        while (index_ > 0) {
            VoidSnap storage voidSnap_ = _unsafeAccess(voidSnaps_, --index_);
            uint256 snapStartingEpoch_ = voidSnap_.startingEpoch;

            if (snapStartingEpoch_ > epoch_) continue;

            return snapStartingEpoch_ == epoch_;
        }
    }

    function _getUnrealizedInflation(address account_, uint256 lastEpoch_) internal view returns (uint256 inflation_) {
        // The balance and delegatee the account had at the epoch are the same since the last sync (by definition).
        uint256 balance_ = _getBalanceWithoutUnrealizedInflation(account_, lastEpoch_);

        if (balance_ == 0) return 0; // No inflation if the account had no balance.

        address delegatee_ = _getDelegatee(account_, lastEpoch_); // Internal avoids `_revertIfNotPastTimepoint`.

        // NOTE: Starting from the epoch after the latest sync, before `lastEpoch_`.
        // NOTE: If account never synced (i.e. it never interacted with the contract nor received tokens or voting
        //       power), then `epoch_` will start at 0, which can result in a longer loop than needed. Inheriting
        //       contracts should override `_getLastSync` to return the most recent appropriate epoch for such an
        //       account, such as the epoch when the contract was deployed, some bootstrap epoch, etc.
        for (uint256 epoch_ = _getLastSync(account_, lastEpoch_) + 1; epoch_ <= lastEpoch_; ++epoch_) {
            // Skip non-voting epochs and epochs when the delegatee did not participate.
            if (!_isVotingEpoch(epoch_) || !_hasParticipatedAt(delegatee_, epoch_)) continue;

            inflation_ += _getInflation(balance_ + inflation_); // Accumulate compounded inflation.
        }
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool) {
        return epoch_ % 2 == 1; // Voting epochs are odd numbered.
    }

    function _revertIfInVoteEpoch() internal view {
        if (_isVotingEpoch(clock())) revert VoteEpoch();
    }

    function _revertIfNotInVoteEpoch() internal view {
        if (!_isVotingEpoch(clock())) revert NotVoteEpoch();
    }

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
