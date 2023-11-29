// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { PureEpochs } from "../libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IEpochBasedInflationaryVoteToken } from "./interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

// TODO: Consider replacing all repetitive internal function calls with cleaner super calls.

// NOTE: There is no feasible way to emit `Transfer` events for inflationary minting such that external client can
//       index them and track balances and total supply correctly. Specifically,a nd only for total supply indexing, one
//       can assume that total supply is the sum of all voting powers, thus tracking the deltas of the
//       `DelegateVotesChanged` events will suffice.

abstract contract EpochBasedInflationaryVoteToken is IEpochBasedInflationaryVoteToken, EpochBasedVoteToken {
    struct VoidWindow {
        uint16 startingEpoch;
    }

    uint256 public constant ONE = 10_000; // 100% in basis points.

    uint256 public immutable participationInflation; // In basis points.

    mapping(address delegatee => VoidWindow[] participationWindows) internal _participations;

    mapping(address account => VoidWindow[] lastSyncWindows) internal _lastSyncs;

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
        return _getLatestValue(_balances[account_]) + _getInflationOf(account_);
    }

    function balanceOfAt(
        address account_,
        uint256 epoch_
    ) public view virtual override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 balance_) {
        return _getValueAt(_balances[account_], epoch_) + _getInflationOfAt(account_, epoch_);
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

    function _markParticipation(address delegatee_) internal virtual onlyDuringVoteEpoch {
        if (!_updateParticipation(delegatee_)) revert AlreadyParticipated();

        uint256 inflation_ = _getInflation(_getLatestValue(_votingPowers[delegatee_]));

        _addTotalSupply(inflation_);
        _addVotingPower(delegatee_, inflation_);
    }

    function _mint(address recipient_, uint256 amount_) internal virtual override notDuringVoteEpoch {
        _sync(recipient_);
        super._mint(recipient_, amount_);
    }

    function _sync(address account_) internal {
        _addBalance(account_, _getInflationOf(account_));
        _update(_lastSyncs[account_], PureEpochs.currentEpoch());
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

    function _update(VoidWindow[] storage voidWindows_, uint256 epoch_) internal returns (bool updated_) {
        uint256 length_ = voidWindows_.length;

        updated_ = (length_ == 0 || epoch_ > _unsafeVoidWindowAccess(voidWindows_, length_ - 1).startingEpoch);

        // If this will be the first or a new VoidWindow, just push it onto the array.
        if (updated_) {
            voidWindows_.push(VoidWindow(uint16(epoch_)));
        }
    }

    function _updateParticipation(address delegatee_) internal returns (bool updated_) {
        return _update(_participations[delegatee_], PureEpochs.currentEpoch());
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _getInflation(uint256 amount_) internal view returns (uint256 inflation_) {
        return (amount_ * participationInflation) / ONE;
    }

    function _getInflationOf(address account_) internal view returns (uint256 inflation_) {
        return _getInflationOfAt(account_, PureEpochs.currentEpoch());
    }

    function _getInflationOfAt(address account_, uint256 lastEpoch_) internal view returns (uint256 inflation_) {
        if (_lastSyncs[account_].length == 0) return 0;

        // The balance and delegate the account has at the epoch is the same value is ever had since the last sync.
        uint256 balance_ = _getValueAt(_balances[account_], lastEpoch_);

        if (balance_ == 0) return 0;

        address delegatee_ = _getDefaultIfZero(_getAccountAt(_delegatees[account_], lastEpoch_), account_);

        for (uint256 epoch_ = _getLatestEpochAt(_lastSyncs[account_], lastEpoch_) + 1; epoch_ <= lastEpoch_; ++epoch_) {
            if (!_isVotingEpoch(epoch_)) continue;

            if (!_getParticipationAt(delegatee_, epoch_)) continue;

            inflation_ += _getInflation(balance_ + inflation_);
        }
    }

    function _getLatestEpoch(VoidWindow[] storage voidWindows_) internal view returns (uint256 latestEpoch_) {
        uint256 length_ = voidWindows_.length;

        return length_ == 0 ? 0 : _unsafeVoidWindowAccess(voidWindows_, length_ - 1).startingEpoch;
    }

    function _getLatestEpochAt(
        VoidWindow[] storage voidWindows_,
        uint256 epoch_
    ) internal view returns (uint256 latestEpoch_) {
        uint256 index_ = voidWindows_.length;

        if (index_ == 0) return 0;

        // Keep going back as long as the epoch is greater or equal to the previous VoidWindow's startingEpoch.
        do {
            VoidWindow storage voidWindow_ = _unsafeVoidWindowAccess(voidWindows_, --index_);

            uint256 voidWindowStartingEpoch_ = voidWindow_.startingEpoch;

            if (voidWindowStartingEpoch_ <= epoch_) return voidWindowStartingEpoch_;
        } while (index_ > 0);
    }

    function _getParticipationAt(address delegatee_, uint256 epoch_) internal view returns (bool participated_) {
        VoidWindow[] storage voidWindows_ = _participations[delegatee_];

        uint256 index_ = voidWindows_.length;

        if (index_ == 0) return false;

        // Keep going back as long as the epoch is greater or equal to the previous VoidWindow's startingEpoch.
        do {
            VoidWindow storage voidWindow_ = _unsafeVoidWindowAccess(voidWindows_, --index_);

            uint256 voidWindowStartingEpoch_ = voidWindow_.startingEpoch;

            if (voidWindowStartingEpoch_ > epoch_) continue;

            return voidWindowStartingEpoch_ == epoch_;
        } while (index_ > 0);
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool isVotingEpoch_) {
        return epoch_ % 2 == 1;
    }

    function _revertIfInVoteEpoch() internal view {
        if (_isVotingEpoch(PureEpochs.currentEpoch())) revert VoteEpoch();
    }

    function _revertIfNotInVoteEpoch() internal view {
        if (!_isVotingEpoch(PureEpochs.currentEpoch())) revert NotVoteEpoch();
    }

    function _unsafeVoidWindowAccess(
        VoidWindow[] storage voidWindows_,
        uint256 index_
    ) internal pure returns (VoidWindow storage voidWindow_) {
        assembly {
            mstore(0, voidWindows_.slot)
            voidWindow_.slot := add(keccak256(0, 0x20), index_)
        }
    }
}
