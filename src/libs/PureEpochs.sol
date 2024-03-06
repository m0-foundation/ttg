// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/**
 * @notice Defines epochs as 15 days away from 'The Merge' timestamp.
 * @author M^0 Labs
 * @dev    Allows for a `uint16` epoch up to timestamp 86,595,288,162 (i.e. Thu, Feb 05, Year 4714, 06:42:42 GMT).
 */
library PureEpochs {
    /* ============ Variables ============ */

    /// @notice The timestamp of The Merge block.
    uint40 internal constant _MERGE_TIMESTAMP = 1_663_224_162;

    /// @notice The approximate target of seconds an epoch should endure.
    uint40 internal constant _EPOCH_PERIOD = 15 days;

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current epoch number.
    function currentEpoch() internal view returns (uint16) {
        return uint16(((block.timestamp - _MERGE_TIMESTAMP) / _EPOCH_PERIOD) + 1); // Epoch at `_MERGE_TIMESTAMP` is 1.
    }

    /// @dev Returns the remaining time in the current epoch.
    function timeRemainingInCurrentEpoch() internal view returns (uint40) {
        return _MERGE_TIMESTAMP + (currentEpoch() * _EPOCH_PERIOD) - uint40(block.timestamp);
    }
}
