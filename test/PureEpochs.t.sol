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
}
