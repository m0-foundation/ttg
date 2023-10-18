// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Test } from "../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../src/PureEpochs.sol";

contract PureEpochsTests is Test {
    function test_currentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.roll(1);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.currentEpoch(), 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.currentEpoch(), 2);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.currentEpoch(), 2);
    }

    function test_startBlockOfCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.startBlockOfCurrentEpoch(), 0);

        vm.roll(1);
        assertEq(PureEpochs.startBlockOfCurrentEpoch(), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.startBlockOfCurrentEpoch(), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.startBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.startBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD);
    }

    function test_endBlockOfCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.endBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(1);
        assertEq(PureEpochs.endBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.endBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.endBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD * 2);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.endBlockOfCurrentEpoch(), PureEpochs._EPOCH_PERIOD * 2);
    }

    function test_blocksElapsedInCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.blocksElapsedInCurrentEpoch(), 0);

        vm.roll(1);
        assertEq(PureEpochs.blocksElapsedInCurrentEpoch(), 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.blocksElapsedInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.blocksElapsedInCurrentEpoch(), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.blocksElapsedInCurrentEpoch(), 1);
    }

    function test_timeElapsedInCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 0);

        vm.roll(1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 12);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 15 days - 12);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.timeElapsedInCurrentEpoch(), 12);
    }

    function test_blocksRemainingInCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(1);
        assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), PureEpochs._EPOCH_PERIOD - 1);
    }

    function test_getTimeRemainingInCurrentEpoch() external {
        vm.roll(0);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 15 days);

        vm.roll(1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 15 days - 12);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 12);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 15 days);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 15 days - 12);
    }

    function test_getBlocksUntilEpochStart() external {
        vm.roll(0);
        assertEq(PureEpochs.getBlocksUntilEpochStart(1), 0);
        assertEq(PureEpochs.getBlocksUntilEpochStart(2), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksUntilEpochStart(3), 2 * PureEpochs._EPOCH_PERIOD);

        vm.roll(1);
        assertEq(PureEpochs.getBlocksUntilEpochStart(2), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksUntilEpochStart(3), 2 * PureEpochs._EPOCH_PERIOD - 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksUntilEpochStart(2), 1);
        assertEq(PureEpochs.getBlocksUntilEpochStart(3), PureEpochs._EPOCH_PERIOD + 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksUntilEpochStart(2), 0);
        assertEq(PureEpochs.getBlocksUntilEpochStart(3), PureEpochs._EPOCH_PERIOD);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksUntilEpochStart(3), PureEpochs._EPOCH_PERIOD - 1);
    }

    function test_getTimeUntilEpochStart() external {
        vm.roll(0);
        assertEq(PureEpochs.getTimeUntilEpochStart(1), 0);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 15 days);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 30 days);

        vm.roll(1);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 15 days - 12);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 30 days - 12);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 12);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 15 days + 12);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochStart(2), 0);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 15 days);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeUntilEpochStart(3), 15 days - 12);
    }

    function test_getBlocksUntilEpochEnds() external {
        vm.roll(0);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(2), PureEpochs._EPOCH_PERIOD * 2);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(3), PureEpochs._EPOCH_PERIOD * 3);

        vm.roll(1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(1), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(2), PureEpochs._EPOCH_PERIOD * 2 - 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(3), PureEpochs._EPOCH_PERIOD * 3 - 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(1), 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(2), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(3), PureEpochs._EPOCH_PERIOD * 2 + 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(1), 0);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(2), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(3), PureEpochs._EPOCH_PERIOD * 2);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(2), PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksUntilEpochEnds(3), PureEpochs._EPOCH_PERIOD * 2 - 1);
    }

    function test_getTimeUntilEpochEnds() external {
        vm.roll(0);
        assertEq(PureEpochs.getTimeUntilEpochEnds(1), 15 days);
        assertEq(PureEpochs.getTimeUntilEpochEnds(2), 30 days);
        assertEq(PureEpochs.getTimeUntilEpochEnds(3), 45 days);

        vm.roll(1);
        assertEq(PureEpochs.getTimeUntilEpochEnds(1), 15 days - 12);
        assertEq(PureEpochs.getTimeUntilEpochEnds(2), 30 days - 12);
        assertEq(PureEpochs.getTimeUntilEpochEnds(3), 45 days - 12);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeUntilEpochEnds(1), 12);
        assertEq(PureEpochs.getTimeUntilEpochEnds(2), 15 days + 12);
        assertEq(PureEpochs.getTimeUntilEpochEnds(3), 30 days + 12);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeUntilEpochEnds(1), 0);
        assertEq(PureEpochs.getTimeUntilEpochEnds(2), 15 days);
        assertEq(PureEpochs.getTimeUntilEpochEnds(3), 30 days);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeUntilEpochEnds(2), 15 days - 12);
        assertEq(PureEpochs.getTimeUntilEpochEnds(3), 30 days - 12);
    }

    function test_getBlocksSinceEpochStart() external {
        vm.roll(0);
        assertEq(PureEpochs.getBlocksSinceEpochStart(1), 0);

        vm.roll(1);
        assertEq(PureEpochs.getBlocksSinceEpochStart(1), 1);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksSinceEpochStart(1), PureEpochs._EPOCH_PERIOD - 1);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksSinceEpochStart(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksSinceEpochStart(2), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksSinceEpochStart(1), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksSinceEpochStart(2), 1);
    }

    function test_getTimeSinceEpochStart() external {
        vm.roll(0);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 0);

        vm.roll(1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 12);

        vm.roll(PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 15 days - 12);

        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 15 days);
        assertEq(PureEpochs.getTimeSinceEpochStart(2), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochStart(1), 15 days + 12);
        assertEq(PureEpochs.getTimeSinceEpochStart(2), 12);
    }

    function test_getBlocksSinceEpochEnd() external {
        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(1), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(1), 1);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD - 1);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(2), 0);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(1), PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getBlocksSinceEpochEnd(2), 1);
    }

    function test_getTimeSinceEpochEnd() external {
        vm.roll(PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 0);

        vm.roll(PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 12);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD - 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 15 days - 12);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 15 days);
        assertEq(PureEpochs.getTimeSinceEpochEnd(2), 0);

        vm.roll(2 * PureEpochs._EPOCH_PERIOD + 1);
        assertEq(PureEpochs.getTimeSinceEpochEnd(1), 15 days + 12);
        assertEq(PureEpochs.getTimeSinceEpochEnd(2), 12);
    }

    function test_getBlockNumberOfEpochStart() external {
        assertEq(PureEpochs.getBlockNumberOfEpochStart(1), 0);
        assertEq(PureEpochs.getBlockNumberOfEpochStart(2), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlockNumberOfEpochStart(3), PureEpochs._EPOCH_PERIOD * 2);
    }

    function test_getBlockNumberOfEpochEnd() external {
        assertEq(PureEpochs.getBlockNumberOfEpochEnd(1), PureEpochs._EPOCH_PERIOD);
        assertEq(PureEpochs.getBlockNumberOfEpochEnd(2), PureEpochs._EPOCH_PERIOD * 2);
        assertEq(PureEpochs.getBlockNumberOfEpochEnd(3), PureEpochs._EPOCH_PERIOD * 3);
    }

    function test_toSeconds() external {
        assertEq(PureEpochs.toSeconds(0), 0);
        assertEq(PureEpochs.toSeconds(1), 12);
        assertEq(PureEpochs.toSeconds(2), 24);
        assertEq(PureEpochs.toSeconds(4), 48);
        assertEq(PureEpochs.toSeconds(8), 96);
        assertEq(PureEpochs.toSeconds(10), 120);
        assertEq(PureEpochs.toSeconds(11), 132);
        assertEq(PureEpochs.toSeconds(12), 144);
        assertEq(PureEpochs.toSeconds(20), 240);
        assertEq(PureEpochs.toSeconds(30), 360);
        assertEq(PureEpochs.toSeconds(31), 372);
        assertEq(PureEpochs.toSeconds(32), 384);
    }
}
