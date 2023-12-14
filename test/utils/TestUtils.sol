// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

contract TestUtils is Test {
    uint256 internal constant EPOCH_LENGTH = 15 days;
    uint256 internal constant START_BLOCK_NUMBER = 17_740_856;
    uint256 internal constant START_BLOCK_TIMESTAMP = 1_689_934_508;

    // Tests start at a voting epoch, at epoch 165
    uint256 internal constant START_EPOCH = START_BLOCK_NUMBER / PureEpochs._EPOCH_PERIOD + 1;

    function _currentEpoch() internal view returns (uint256) {
        return PureEpochs.currentEpoch();
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool) {
        return epoch_ % 2 == 1;
    }

    function _isTransferEpoch(uint256 epoch_) internal pure returns (bool) {
        return epoch_ % 2 == 0;
    }

    function _goToNextEpoch() internal {
        _jumpToEpoch(PureEpochs.currentEpoch() + 1);
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

    function _getInflationReward(IPowerToken powerToken_, uint256 powerWeight_) internal view returns (uint256) {
        return (powerWeight_ * powerToken_.participationInflation()) / powerToken_.ONE();
    }

    function _getNextTargetSupply(IPowerToken powerToken_) internal view returns (uint256) {
        uint256 _targetSupply = powerToken_.targetSupply();
        return _targetSupply + (_targetSupply * powerToken_.participationInflation()) / powerToken_.ONE();
    }

    function _getZeroTokenReward(
        IStandardGovernor standardGovernor_,
        uint256 powerWeight_,
        IPowerToken powerToken_,
        uint256 voteStart_
    ) internal view returns (uint256) {
        return
            (standardGovernor_.maxTotalZeroRewardPerActiveEpoch() * powerWeight_) /
            powerToken_.pastTotalSupply(voteStart_);
    }

    function _hashProposal(
        bytes memory callData_,
        uint256 voteStart_,
        address governor_
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(callData_, voteStart_, governor_)));
    }
}
