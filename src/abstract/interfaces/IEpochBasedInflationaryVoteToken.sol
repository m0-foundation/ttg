// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedVoteToken } from "./IEpochBasedVoteToken.sol";

/**
 * @title  Extension for an EpochBasedVoteToken token that allows for inflating tokens and voting power.
 * @author M^0 Labs
 */
interface IEpochBasedInflationaryVoteToken is IEpochBasedVoteToken {
    /* ============ Events ============ */

    /**
     * @notice Emitted when `account` is manually synced.
     * @param  account The address of an account that is synced.
     */
    event Sync(address indexed account);

    /* ============ Custom Errors ============ */

    /// @notice Revert message when trying to mark an account as participated in an epoch where it already participated.
    error AlreadyParticipated();

    /**
     * @notice Revert message when the proposed epoch is larger than the current epoch.
     * @param  currentEpoch The current epoch clock value.
     * @param  epoch        The handled epoch clock value.
     */
    error FutureEpoch(uint16 currentEpoch, uint16 epoch);

    /// @notice Revert message when trying to construct contact with inflation above 100%.
    error InflationTooHigh();

    /// @notice Revert message when trying to perform an action not allowed outside of designated voting epochs.
    error NotVoteEpoch();

    /// @notice Revert message when trying to perform an action not allowed during designated voting epochs.
    error VoteEpoch();

    /* ============ Interactive Functions ============ */

    /**
     * @dev   Syncs `account` so that its balance Snap array in storage, reflects their unrealized inflation.
     * @param account The address of the account to sync.
     */
    function sync(address account) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns whether `delegatee` has participated in voting during clock value `epoch`.
     * @param  delegatee The address of a delegatee with voting power.
     * @param  epoch     The epoch number as a clock value.
     * @return Whether `delegatee` has participated in voting during `epoch`.
     */
    function hasParticipatedAt(address delegatee, uint256 epoch) external view returns (bool);

    /// @notice Returns the participation inflation rate used to inflate tokens for participation.
    function participationInflation() external view returns (uint16);

    /// @notice Returns 100% in basis point, to be used to correctly ascertain the participation inflation rate.
    function ONE() external pure returns (uint16);
}
