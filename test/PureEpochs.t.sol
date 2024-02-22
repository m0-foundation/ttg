// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../src/libs/PureEpochs.sol";

contract PureEpochsTests is Test {
    function test_currentEpoch() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.currentEpoch(), 2);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.currentEpoch(), 2);
    }

    function test_getTimestampOfEpochStart() external {
        assertEq(PureEpochs.getTimestampOfEpochStart(1), PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.getTimestampOfEpochStart(2), PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimestampOfEpochStart(3), PureEpochs._MERGE_TIMESTAMP + 2 * PureEpochs._EPOCH_PERIOD);
    }

    function test_getTimestampOfEpochEnd() external {
        assertEq(PureEpochs.getTimestampOfEpochEnd(1), PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimestampOfEpochEnd(2), PureEpochs._MERGE_TIMESTAMP + 2 * PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimestampOfEpochEnd(3), PureEpochs._MERGE_TIMESTAMP + 3 * PureEpochs._EPOCH_PERIOD);
    }

    function test_timeElapsedInCurrentEpoch() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 1);
    }

    function test_timeRemainingInCurrentEpoch() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);
    }

    function test_getTimeUntilEpochStart() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.getTimeUntilEpochStart(1), 0);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 2 * PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), (2 * PureEpochs._EPOCH_PERIOD) - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), PureEpochs._EPOCH_PERIOD + 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 0);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), PureEpochs._EPOCH_PERIOD - 1);
    }

    function test_getTimeUntilEpochEnd() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.getTimeUntilEpochEnd(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochEnd(2), 2 * PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochEnd(3), 3 * PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(1), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(2), (2 * PureEpochs._EPOCH_PERIOD) - 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(3), (3 * PureEpochs._EPOCH_PERIOD) - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(1), 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(2), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(3), (2 * PureEpochs._EPOCH_PERIOD) + 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochEnd(1), 0);
        assertEq(PureEpochs.getTimeUntilEpochEnd(2), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochEnd(3), 2 * PureEpochs._EPOCH_PERIOD);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(2), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochEnd(3), (2 * PureEpochs._EPOCH_PERIOD) - 1);
    }

    function test_getTimeSinceEpochStart() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), PureEpochs._EPOCH_PERIOD - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochStart(2), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(2), 1);
    }

    function test_getTimeSinceEpochEnd() external {
        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 2 * PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD - 1);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 2 * PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochEnd(2), 0);

        vm.warp(PureEpochs._MERGE_TIMESTAMP + 2 * PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(2), 1);
    }
}
