// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @notice Defines epochs as 15 days worth of blocks (108,000) away from 'The Merge' block.
library PureEpochs {
    /// @notice The number of seconds in a block.
    uint256 internal constant _SECONDS_PER_BLOCK = 12;

    uint256 internal constant _EPOCH_PERIOD = 15 days / _SECONDS_PER_BLOCK;

    function currentEpoch() internal view returns (uint256 currentEpoch_) {
        return (block.number / _EPOCH_PERIOD) + 1; // Epoch at block 0 is 1.
    }

    function startBlockOfCurrentEpoch() internal view returns (uint256 startBlock_) {
        return getBlockNumberOfEpochStart(currentEpoch());
    }

    function endBlockOfCurrentEpoch() internal view returns (uint256 endBlock_) {
        return getBlockNumberOfEpochStart(currentEpoch() + 1);
    }

    function blocksElapsedInCurrentEpoch() internal view returns (uint256 blocks_) {
        return block.number - startBlockOfCurrentEpoch();
    }

    function timeElapsedInCurrentEpoch() internal view returns (uint256 time_) {
        return toSeconds(blocksElapsedInCurrentEpoch());
    }

    function blocksRemainingInCurrentEpoch() internal view returns (uint256 blocks_) {
        return endBlockOfCurrentEpoch() - block.number;
    }

    function timeRemainingInCurrentEpoch() internal view returns (uint256 time_) {
        return toSeconds(blocksRemainingInCurrentEpoch());
    }

    function getBlocksUntilEpochStart(uint256 epoch) internal view returns (uint256 blocks_) {
        return getBlockNumberOfEpochStart(epoch) - block.number;
    }

    function getTimeUntilEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        return toSeconds(getBlocksUntilEpochStart(epoch));
    }

    function getBlocksUntilEpochEnds(uint256 epoch) internal view returns (uint256 blocks_) {
        return getBlockNumberOfEpochStart(epoch + 1) - block.number;
    }

    function getTimeUntilEpochEnds(uint256 epoch) internal view returns (uint256 time_) {
        return toSeconds(getBlocksUntilEpochEnds(epoch));
    }

    function getBlocksSinceEpochStart(uint256 epoch) internal view returns (uint256 blocks_) {
        return block.number - getBlockNumberOfEpochStart(epoch);
    }

    function getTimeSinceEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        return toSeconds(getBlocksSinceEpochStart(epoch));
    }

    function getBlocksSinceEpochEnd(uint256 epoch) internal view returns (uint256 blocks_) {
        return block.number - getBlockNumberOfEpochStart(epoch + 1);
    }

    function getTimeSinceEpochEnd(uint256 epoch) internal view returns (uint256 time_) {
        return toSeconds(getBlocksSinceEpochEnd(epoch));
    }

    function getBlockNumberOfEpochStart(uint256 epoch) internal pure returns (uint256 blockNumber_) {
        return (epoch - 1) * _EPOCH_PERIOD;
    }

    function getBlockNumberOfEpochEnd(uint256 epoch) internal pure returns (uint256 blockNumber_) {
        return getBlockNumberOfEpochStart(epoch + 1);
    }

    function toSeconds(uint256 blocks_) internal pure returns (uint256 seconds_) {
        return blocks_ * _SECONDS_PER_BLOCK;
    }
}
