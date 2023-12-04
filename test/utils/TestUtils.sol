// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

contract TestUtils is Test {
    function _goToNextEpoch() internal {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        _jumpToEpoch(currentEpoch_ + 1);
    }

    function _goToNextVoteEpoch() internal {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ % 2 == 1) {
            _jumpToEpoch(currentEpoch_ + 2);
        } else {
            _jumpToEpoch(currentEpoch_ + 1);
        }
    }

    function _goToNextTransferEpoch() internal {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ % 2 == 1) {
            _jumpToEpoch(currentEpoch_ + 1);
        } else {
            _jumpToEpoch(currentEpoch_ + 2);
        }
    }

    function _jumpToEpoch(uint256 epoch_) internal {
        _jumpBlocks(PureEpochs.getBlocksUntilEpochStart(epoch_));
    }

    function _jumpBlocks(uint256 blocks_) internal {
        vm.roll(block.number + blocks_);
        vm.warp(block.timestamp + (blocks_ * PureEpochs._SECONDS_PER_BLOCK));
    }
}
