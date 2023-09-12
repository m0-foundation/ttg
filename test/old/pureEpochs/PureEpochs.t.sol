// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import { PureEpochs } from "../../src/pureEpochs/PureEpochs.sol";

// import { Test } from "../ImportedContracts.sol";

// contract PureEpochsTests is Test {
//     uint256 internal constant _30_DAYS_OF_BLOCKS = 216_000;

//     function test_currentEpoch() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.currentEpoch(), 0);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.currentEpoch(), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.currentEpoch(), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.currentEpoch(), 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.currentEpoch(), 1);
//     }

//     function test_getBlockNumberOfEpochStart() external {
//         assertEq(PureEpochs.getBlockNumberOfEpochStart(0), PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getBlockNumberOfEpochStart(1), PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlockNumberOfEpochStart(2), PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS * 2);
//     }

//     function test_blocksRemainingInCurrentEpoch() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), _30_DAYS_OF_BLOCKS);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), _30_DAYS_OF_BLOCKS - 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), _30_DAYS_OF_BLOCKS);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.blocksRemainingInCurrentEpoch(), _30_DAYS_OF_BLOCKS - 1);
//     }

//     function test_getTimeRemainingInCurrentEpoch() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 30 days);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 30 days - 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 30 days);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.timeRemainingInCurrentEpoch(), 30 days - 12);
//     }

//     function test_getBlocksUntilEpochStart() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(0), 0);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(1), _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(2), 2 * _30_DAYS_OF_BLOCKS);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(1), _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(2), 2 * _30_DAYS_OF_BLOCKS - 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(1), 1);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(2), _30_DAYS_OF_BLOCKS + 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(1), 0);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(2), _30_DAYS_OF_BLOCKS);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksUntilEpochStart(2), _30_DAYS_OF_BLOCKS - 1);
//     }

//     function test_getTimeUntilEpochStart() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getTimeUntilEpochStart(0), 0);
//         assertEq(PureEpochs.getTimeUntilEpochStart(1), 30 days);
//         assertEq(PureEpochs.getTimeUntilEpochStart(2), 60 days);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getTimeUntilEpochStart(1), 30 days - 12);
//         assertEq(PureEpochs.getTimeUntilEpochStart(2), 60 days - 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getTimeUntilEpochStart(1), 12);
//         assertEq(PureEpochs.getTimeUntilEpochStart(2), 30 days + 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getTimeUntilEpochStart(1), 0);
//         assertEq(PureEpochs.getTimeUntilEpochStart(2), 30 days);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getTimeUntilEpochStart(2), 30 days - 12);
//     }

//     function test_getBlocksUntilEpochEnds() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(0), _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(1), _30_DAYS_OF_BLOCKS * 2);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(2), _30_DAYS_OF_BLOCKS * 3);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(0), _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(1), _30_DAYS_OF_BLOCKS * 2 - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(2), _30_DAYS_OF_BLOCKS * 3 - 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(0), 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(1), _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(2), _30_DAYS_OF_BLOCKS * 2 + 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(0), 0);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(1), _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(2), _30_DAYS_OF_BLOCKS * 2);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(1), _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksUntilEpochEnds(2), _30_DAYS_OF_BLOCKS * 2 - 1);
//     }

//     function test_getTimeUntilEpochEnds() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(0), 30 days);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(1), 60 days);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(2), 90 days);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(0), 30 days - 12);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(1), 60 days - 12);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(2), 90 days - 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(0), 12);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(1), 30 days + 12);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(2), 60 days + 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(0), 0);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(1), 30 days);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(2), 60 days);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(1), 30 days - 12);
//         assertEq(PureEpochs.getTimeUntilEpochEnds(2), 60 days - 12);
//     }

//     function test_getBlocksSinceEpochStart() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(0), 0);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(0), 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(0), _30_DAYS_OF_BLOCKS - 1);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(0), _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(1), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(0), _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochStart(1), 1);
//     }

//     function test_getTimeSinceEpochStart() external {
//         vm.roll(PureEpochs._START_BLOCK);
//         assertEq(PureEpochs.getTimeSinceEpochStart(0), 0);

//         vm.roll(PureEpochs._START_BLOCK + 1);
//         assertEq(PureEpochs.getTimeSinceEpochStart(0), 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getTimeSinceEpochStart(0), 30 days - 12);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getTimeSinceEpochStart(0), 30 days);
//         assertEq(PureEpochs.getTimeSinceEpochStart(1), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getTimeSinceEpochStart(0), 30 days + 12);
//         assertEq(PureEpochs.getTimeSinceEpochStart(1), 12);
//     }

//     function test_getBlocksSinceEpochEnd() external {
//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(0), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(0), 1);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(0), _30_DAYS_OF_BLOCKS - 1);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(0), _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(1), 0);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(0), _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getBlocksSinceEpochEnd(1), 1);
//     }

//     function test_getTimeSinceEpochEnd() external {
//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(0), 0);

//         vm.roll(PureEpochs._START_BLOCK + _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(0), 12);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS - 1);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(0), 30 days - 12);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(0), 30 days);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(1), 0);

//         vm.roll(PureEpochs._START_BLOCK + 2 * _30_DAYS_OF_BLOCKS + 1);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(0), 30 days + 12);
//         assertEq(PureEpochs.getTimeSinceEpochEnd(1), 12);
//     }

//     function test_toSeconds() external {
//         assertEq(PureEpochs.toSeconds(0), 0);
//         assertEq(PureEpochs.toSeconds(1), 12);
//         assertEq(PureEpochs.toSeconds(2), 24);
//         assertEq(PureEpochs.toSeconds(4), 48);
//         assertEq(PureEpochs.toSeconds(8), 96);
//         assertEq(PureEpochs.toSeconds(10), 120);
//         assertEq(PureEpochs.toSeconds(11), 132);
//         assertEq(PureEpochs.toSeconds(12), 144);
//         assertEq(PureEpochs.toSeconds(20), 240);
//         assertEq(PureEpochs.toSeconds(30), 360);
//         assertEq(PureEpochs.toSeconds(31), 372);
//         assertEq(PureEpochs.toSeconds(32), 384);
//     }
// }
