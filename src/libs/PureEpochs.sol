// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/**
 * @notice Defines epochs as periods away from STATING_TIMESTAMP timestamp.
 * @author M^0 Labs
 * @dev    Provides a `uint16` epoch clock value.
 */
library PureEpochs {
    /* ============ Variables ============ */

    /// @notice The timestamp of the start of Epoch 1.
    uint40 internal constant STARTING_TIMESTAMP = 1_663_224_162;

    /// @notice The approximate target of seconds an epoch should endure.
    uint40 internal constant EPOCH_PERIOD = 15 days;

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current epoch number.
    function currentEpoch() internal view returns (uint16) {
        return uint16(((block.timestamp - STARTING_TIMESTAMP) / EPOCH_PERIOD) + 1);
    }

    /// @dev Returns the remaining time in the current epoch.
    function timeRemainingInCurrentEpoch() internal view returns (uint40) {
        return STARTING_TIMESTAMP + (currentEpoch() * EPOCH_PERIOD) - uint40(block.timestamp);
    }
}
