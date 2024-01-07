// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedVoteToken } from "./IEpochBasedVoteToken.sol";

/// @title Extension for an EpochBasedVoteToken token that allows for inflating tokens and voting power.
interface IEpochBasedInflationaryVoteToken is IEpochBasedVoteToken {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /// @notice Revert message when trying to mark an account as participated in an epoch where it already participated.
    error AlreadyParticipated();

    /// @notice Revert message when trying to construct contact with inflation above 100%.
    error InflationTooHigh();

    /// @notice Revert message when trying to perform an action not allowed outside of designated voting epochs.
    error NotVoteEpoch();

    /// @notice Revert message when trying to perform an action not allowed during designated voting epochs.
    error VoteEpoch();

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns 100% in basis point, to be used to correctly ascertain the participation inflation rate.
     * @return 100% in basis point.
     */
    function ONE() external pure returns (uint16);

    /**
     * @notice Returns whether `delegatee` has participated in voting during clock value `epoch`.
     * @param  delegatee    The address of a delegatee with voting power.
     * @param  epoch        The epoch number as a clock value.
     * @return  Whether `delegatee` has participated in voting during `epoch`.
     */
    function hasParticipatedAt(address delegatee, uint256 epoch) external view returns (bool);

    /**
     * @notice Returns the participation inflation rate used to inflate tokens for participation.
     * @return Participation inflation rate.
     */
    function participationInflation() external view returns (uint16);
}
