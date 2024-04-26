// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

contract TestUtils is Test {
    uint256 internal immutable START_BLOCK_TIMESTAMP = vm.getBlockTimestamp();

    // Tests start at a voting epoch, at epoch 165
    uint256 internal immutable START_EPOCH =
        ((START_BLOCK_TIMESTAMP - PureEpochs.STARTING_TIMESTAMP) / PureEpochs.EPOCH_PERIOD) + 1;

    function _currentEpoch() internal view returns (uint16) {
        return PureEpochs.currentEpoch();
    }

    function _isVotingEpoch(uint256 epoch_) internal pure returns (bool) {
        return epoch_ % 2 == 1;
    }

    function _isTransferEpoch(uint256 epoch_) internal pure returns (bool) {
        return !_isVotingEpoch(epoch_);
    }

    function _warpToNextEpoch() internal {
        _jumpEpochs(1);
    }

    function _warpToNextVoteEpoch() internal {
        _jumpEpochs(_isVotingEpoch(PureEpochs.currentEpoch()) ? 2 : 1);
    }

    function _warpToNextTransferEpoch() internal {
        _jumpEpochs(_isVotingEpoch(PureEpochs.currentEpoch()) ? 1 : 2);
    }

    function _getTimestampOfEpochStart(uint16 epoch) internal pure returns (uint40 timestamp_) {
        return PureEpochs.STARTING_TIMESTAMP + (epoch - 1) * PureEpochs.EPOCH_PERIOD;
    }

    function _warpToEpoch(uint256 epoch_) internal {
        vm.warp(_getTimestampOfEpochStart(uint16(epoch_)));
    }

    function _warpToTheEndOfTheEpoch(uint256 epoch_) internal {
        vm.warp(_getTimestampOfEpochStart(uint16(epoch_) + 1) - 1);
    }

    function _jumpEpochs(uint256 epochs_) internal {
        vm.warp(_getTimestampOfEpochStart(PureEpochs.currentEpoch() + uint16(epochs_)));
    }

    function _jumpSeconds(uint256 seconds_) internal {
        vm.warp(vm.getBlockTimestamp() + seconds_);
    }

    function _getNextVotingPower(address voter_, IPowerToken powerToken_) internal view returns (uint240) {
        uint256 votingPower_ = powerToken_.getVotes(voter_);
        return uint240(votingPower_ + (votingPower_ * powerToken_.participationInflation()) / powerToken_.ONE());
    }

    function _getNextTargetSupply(IPowerToken powerToken_) internal view returns (uint240) {
        uint256 targetSupply_ = powerToken_.targetSupply();
        return uint240(targetSupply_ + (targetSupply_ * powerToken_.participationInflation()) / powerToken_.ONE());
    }

    function _getZeroTokenReward(
        address voter_,
        IPowerToken powerToken_,
        IStandardGovernor standardGovernor_,
        uint256 voteStart_
    ) internal view returns (uint256) {
        // maxTotalZeroRewardPerActiveEpoch * votingWeight / pastTotalSupply
        return
            (standardGovernor_.maxTotalZeroRewardPerActiveEpoch() * powerToken_.getPastVotes(voter_, voteStart_ - 1)) /
            powerToken_.pastTotalSupply(voteStart_ - 1);
    }

    function _hashProposal(
        bytes memory callData_,
        uint256 voteStart_,
        address governor_
    ) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(callData_, voteStart_, governor_)));
    }

    function _getSignature(bytes32 digest_, uint256 privateKey_) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey_, digest_);

        return abi.encodePacked(r, s, v);
    }

    function _makeKey(string memory name) internal returns (uint256 privateKey) {
        (, privateKey) = makeAddrAndKey(name);
    }
}
