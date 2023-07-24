// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/// @title PureEpochs
/// @notice Defines epochs as 30 days worth of blocks (216,000) away from 'The Merge' block.
library PureEpochs {
    // Ethereum finalized 'The Merge' at block 15_537_393 on September 15, 2022, at 05:42:42 GMT.
    uint256 internal constant _START_BLOCK = 15_537_393;

    uint256 internal constant _SECONDS_PER_BLOCK = 12;

    uint256 internal constant _EPOCH_PERIOD = 216_000; // 30 days in blocks

    function currentEpoch() internal view returns (uint256 currentEpoch_) {
        currentEpoch_ = (block.number - _START_BLOCK) / _EPOCH_PERIOD;
    }

    function getBlockNumberOfEpochStart(uint256 epoch) internal pure returns (uint256 blockNumber_) {
        blockNumber_ = _START_BLOCK + (epoch * _EPOCH_PERIOD);
    }

    function blocksRemainingInCurrentEpoch() internal view returns (uint256 blocks_) {
        blocks_ = getBlockNumberOfEpochStart(currentEpoch() + 1) - block.number;
    }

    function timeRemainingInCurrentEpoch() internal view returns (uint256 time_) {
        time_ = toSeconds(blocksRemainingInCurrentEpoch());
    }

    function getBlocksUntilEpochStart(uint256 epoch) internal view returns (uint256 blocks_) {
        blocks_ = getBlockNumberOfEpochStart(epoch) - block.number;
    }

    function getTimeUntilEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        time_ = toSeconds(getBlocksUntilEpochStart(epoch));
    }

    function getBlocksUntilEpochEnds(uint256 epoch) internal view returns (uint256 blocks_) {
        blocks_ = getBlockNumberOfEpochStart(epoch + 1) - block.number;
    }

    function getTimeUntilEpochEnds(uint256 epoch) internal view returns (uint256 time_) {
        time_ = toSeconds(getBlocksUntilEpochEnds(epoch));
    }

    function getBlocksSinceEpochStart(uint256 epoch) internal view returns (uint256 blocks_) {
        blocks_ = block.number - getBlockNumberOfEpochStart(epoch);
    }

    function getTimeSinceEpochStart(uint256 epoch) internal view returns (uint256 time_) {
        time_ = toSeconds(getBlocksSinceEpochStart(epoch));
    }

    function getBlocksSinceEpochEnd(uint256 epoch) internal view returns (uint256 blocks_) {
        blocks_ = block.number - getBlockNumberOfEpochStart(epoch + 1);
    }

    function getTimeSinceEpochEnd(uint256 epoch) internal view returns (uint256 time_) {
        time_ = toSeconds(getBlocksSinceEpochEnd(epoch));
    }

    function toSeconds(uint256 blocks_) internal pure returns (uint256 seconds_) {
        seconds_ = blocks_ * _SECONDS_PER_BLOCK;
    }
}
