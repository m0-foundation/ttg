// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IEpochBasedInflationaryVoteToken } from "./interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

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

    function balanceOf(
        address account_
    ) public view virtual override(IERC20, EpochBasedVoteToken) returns (uint256 balance_) {
        // NOTE: `super.balanceOf` already includes realized inflation before the account's last sync.
        return super.balanceOf(account_) + _getUnrealizedInflationOf(account_);
    }

    function pastBalanceOf(
        address account_,
        uint256 epoch_
    ) public view virtual override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 balance_) {
        // NOTE: `super.pastBalanceOf` already includes realized inflation before the account's last sync at that epoch.
        return super.pastBalanceOf(account_, epoch_) + _getUnrealizedInflationOfAt(account_, epoch_);
    }

    function hasParticipatedAt(address delegatee_, uint256 epoch_) external view returns (bool participated_) {
        return _getParticipationAt(delegatee_, epoch_);
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

        uint256 inflation_ = _getInflation(getVotes(delegatee_));

        _addTotalSupply(inflation_);
        _addVotingPower(delegatee_, inflation_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual override notDuringVoteEpoch {
        _sync(recipient_);
        super._mint(recipient_, amount_);
    }

    function _sync(address account_) internal {
        // Realized the account's unrealized inflation since the its last sync, and update its last sync.
        _addBalance(account_, _getUnrealizedInflationOf(account_));
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
        uint16 currentEpoch_ = uint16(PureEpochs.currentEpoch());
        uint256 length_ = voidSnaps_.length;

        // If this will be the first or a new VoidSnap, just push it onto the array.
        if (updated_ = ((length_ == 0) || (currentEpoch_ > _unsafeAccess(voidSnaps_, length_ - 1).startingEpoch))) {
            voidSnaps_.push(VoidSnap(currentEpoch_));
        }
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getInflation(uint256 amount_) internal view returns (uint256 inflation_) {
        return (amount_ * participationInflation) / ONE;
    }

    function _getUnrealizedInflationOf(address account_) internal view returns (uint256 inflation_) {
        return _getUnrealizedInflationOfAt(account_, PureEpochs.currentEpoch());
    }

    function _getUnrealizedInflationOfAt(
        address account_,
        uint256 lastEpoch_
    ) internal view returns (uint256 inflation_) {
        if (_lastSyncs[account_].length == 0) return 0;

        // The balance and delegatee the account had at the epoch are the same since the last sync (by definition).
        uint256 balance_ = _getValueAt(_balances[account_], lastEpoch_); // Internal avoids `_revertIfNotPastTimepoint`.

        if (balance_ == 0) return 0; // No inflation if the account had no balance.

        address delegatee_ = _getDelegateeAt(account_, lastEpoch_); // Internal avoids `_revertIfNotPastTimepoint`.

        // NOTE: Starting from the epoch after the latest sync, before `lastEpoch_`.
        for (uint256 epoch_ = _getLatestEpochAt(_lastSyncs[account_], lastEpoch_) + 1; epoch_ <= lastEpoch_; ++epoch_) {
            // Skip non-voting epochs and epochs when the delegatee did not participate.
            if (!_isVotingEpoch(epoch_) || !_getParticipationAt(delegatee_, epoch_)) continue;

            inflation_ += _getInflation(balance_ + inflation_); // Accumulate compounded inflation.
        }
    }

    /// @dev While confusing, this function retrieves the startingEpoch of the VoidSnap most recent to `epoch_`.
    function _getLatestEpochAt(
        VoidSnap[] storage voidSnaps_,
        uint256 epoch_
    ) internal view returns (uint256 latestEpoch_) {
        uint256 index_ = voidSnaps_.length;

        // Keep going back until we find the first snap with a startingEpoch less than or equal to `epoch_`. This snap
        // is the most recent to `epoch_`, so return its startingEpoch. If we exhaust the array, then it's 0.
        while (index_ > 0) {
            VoidSnap storage voidSnap_ = _unsafeAccess(voidSnaps_, --index_);
            uint256 snapStartingEpoch_ = voidSnap_.startingEpoch;

            if (snapStartingEpoch_ <= epoch_) return snapStartingEpoch_;
        }
    }

    function _getParticipationAt(address delegatee_, uint256 epoch_) internal view returns (bool participated_) {
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

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        return epoch_ % 2 == 1; // Voting epochs are odd numbered.
    }

    function _revertIfInVoteEpoch() internal view {
        if (_isVotingEpoch(PureEpochs.currentEpoch())) revert VoteEpoch();
    }

    function _revertIfNotInVoteEpoch() internal view {
        if (!_isVotingEpoch(PureEpochs.currentEpoch())) revert NotVoteEpoch();
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
