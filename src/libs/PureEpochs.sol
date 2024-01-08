// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @notice Defines epochs as 15 days away from 'The Merge' timestamp.
/// @dev    Allows for a `uint16` epoch up to timestamp 86,595,288,162 (i.e. Thu, Feb 05, Year 4714, 06:42:42 GMT).
library PureEpochs {
    /// @notice The timestamp of The Merge block.
    uint40 internal constant _MERGE_TIMESTAMP = 1_663_224_162;

    /// @notice The approximate target of seconds an epoch should endure.
    uint40 internal constant _EPOCH_PERIOD = 15 days;

    function currentEpoch() internal view returns (uint16 currentEpoch_) {
        return uint16(((block.timestamp - _MERGE_TIMESTAMP) / _EPOCH_PERIOD) + 1); // Epoch at `_MERGE_TIMESTAMP` is 1.
    }

    function timeElapsedInCurrentEpoch() internal view returns (uint40 time_) {
        return uint40(block.timestamp) - getTimestampOfEpochStart(currentEpoch());
    }

    function timeRemainingInCurrentEpoch() internal view returns (uint40 time_) {
        return getTimestampOfEpochEnd(currentEpoch()) - uint40(block.timestamp);
    }

    function getTimeUntilEpochStart(uint16 epoch) internal view returns (uint40 time_) {
        return getTimestampOfEpochStart(epoch) - uint40(block.timestamp);
    }

    function getTimeUntilEpochEnds(uint16 epoch) internal view returns (uint40 time_) {
        return getTimestampOfEpochEnd(epoch) - uint40(block.timestamp);
    }

    function getTimeSinceEpochStart(uint16 epoch) internal view returns (uint40 time_) {
        return uint40(block.timestamp) - getTimestampOfEpochStart(epoch);
    }

    function getTimeSinceEpochEnd(uint16 epoch) internal view returns (uint40 time_) {
        return uint40(block.timestamp) - getTimestampOfEpochEnd(epoch);
    }

    function getTimestampOfEpochStart(uint16 epoch) internal pure returns (uint40 timestamp_) {
        return _MERGE_TIMESTAMP + (epoch - 1) * _EPOCH_PERIOD;
    }

    function getTimestampOfEpochEnd(uint16 epoch) internal pure returns (uint40 timestamp_) {
        return getTimestampOfEpochStart(epoch + 1);
    }
}
