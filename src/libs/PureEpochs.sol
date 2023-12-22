// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @notice Defines epochs as 15 days away from 'The Merge' timestamp.
/// @dev    Allows for a `uint16` epoch up to timestamp 86,595,288,162 (i.e. Thu, Feb 05, Year 4714, 06:42:42 GMT).
library PureEpochs {
    /// @notice The timestamp of The Merge block.
    uint256 internal constant _MERGE_TIMESTAMP = 1_663_224_162;

    /// @notice The approximate target of seconds an epoch should endure.
    uint256 internal constant _EPOCH_PERIOD = 15 days;

    function currentEpoch() internal view returns (uint256 currentEpoch_) {
        return ((block.timestamp - _MERGE_TIMESTAMP) / _EPOCH_PERIOD) + 1; // Epoch at `_MERGE_TIMESTAMP` is 1.
    }

    function getTimestampOfEpochStart(uint256 epoch) internal pure returns (uint256 timestamp_) {
        return _MERGE_TIMESTAMP + (epoch - 1) * _EPOCH_PERIOD;
    }

    function getTimestampOfEpochEnd(uint256 epoch) internal pure returns (uint256 timestamp_) {
        return getTimestampOfEpochStart(epoch + 1);
    }

    function timeElapsedInCurrentEpoch() internal view returns (uint256 time_) {
        return block.timestamp - getTimestampOfEpochStart(currentEpoch());
    }

    function timeRemainingInCurrentEpoch() internal view returns (uint256 time_) {
        return getTimestampOfEpochEnd(currentEpoch()) - block.timestamp;
    }

    function getTimeUntilEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        return getTimestampOfEpochStart(epoch) - block.timestamp;
    }

    function getTimeUntilEpochEnds(uint256 epoch) internal view returns (uint256 time_) {
        return getTimestampOfEpochEnd(epoch) - block.timestamp;
    }

    function getTimeSinceEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        return block.timestamp - getTimestampOfEpochStart(epoch);
    }

    function getTimeSinceEpochEnd(uint256 epoch) internal view returns (uint256 time_) {
        return block.timestamp - getTimestampOfEpochEnd(epoch);
    }
}
