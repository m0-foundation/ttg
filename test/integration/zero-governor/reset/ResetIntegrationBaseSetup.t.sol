// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../../../../lib/common/src/interfaces/IERC20.sol";

import {
    IntegrationBaseSetup,
    IBatchGovernor,
    IGovernor,
    IZeroGovernor,
    IEmergencyGovernor,
    IStandardGovernor
} from "../../IntegrationBaseSetup.t.sol";

/// @notice Common setup for reset integration tests
abstract contract ResetIntegrationBaseSetup is IntegrationBaseSetup {
    function _revertIfGovernorsAreNotFunctional(
        IStandardGovernor standardGovernor_,
        IEmergencyGovernor emergencyGovernor_,
        address[] memory powerUsers_
    ) internal {
        IERC20 powerToken_ = IERC20(standardGovernor_.voteToken());

        _warpToNextTransferEpoch();

        address[] memory targets1_ = new address[](1);
        targets1_[0] = address(emergencyGovernor_);

        address[] memory targets2_ = new address[](1);
        targets2_[0] = address(standardGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas1_ = new bytes[](1);
        callDatas1_[0] = abi.encodeWithSelector(
            emergencyGovernor_.removeFromAndAddToList.selector,
            bytes32("MintersList"),
            _dave,
            _eve
        );

        bytes[] memory callDatas2_ = new bytes[](1);
        callDatas2_[0] = abi.encodeWithSelector(
            standardGovernor_.removeFromAndAddToList.selector,
            bytes32("MintersList"),
            _dave,
            _eve
        );

        vm.prank(powerUsers_[0]);
        uint256 proposalId1_ = emergencyGovernor_.propose(targets1_, values_, callDatas1_, "Emergency Proposal");

        vm.prank(powerUsers_[0]);
        _cashToken1.approve(address(standardGovernor_), _cashToken1MaxAmount);

        vm.prank(powerUsers_[0]);
        uint256 proposalId2_ = standardGovernor_.propose(targets2_, values_, callDatas2_, "Standard Proposal");

        vm.prank(powerUsers_[1]);
        emergencyGovernor_.castVote(proposalId1_, 1);

        vm.prank(powerUsers_[2]);
        emergencyGovernor_.castVote(proposalId1_, 1);

        assertEq(uint256(emergencyGovernor_.state(proposalId1_)), 4); // Succeeded

        _warpToNextEpoch();

        uint256 userPowerBalanceBeforeVoting_ = powerToken_.balanceOf(powerUsers_[1]);
        uint256 userZeroBalanceBeforeVoting_ = _zeroToken.balanceOf(powerUsers_[1]);

        vm.prank(powerUsers_[1]);
        standardGovernor_.castVote(proposalId2_, 1);

        // ZERO rewards still works
        assertEq(
            _zeroToken.balanceOf(powerUsers_[1]),
            userZeroBalanceBeforeVoting_ + (5_000_000e6 * userPowerBalanceBeforeVoting_) / 10_000
        );

        emergencyGovernor_.execute(targets1_, values_, callDatas1_, bytes32(0));

        _warpToNextEpoch();

        // POWER Inflation still works
        assertEq(powerToken_.balanceOf(powerUsers_[1]), (110 * userPowerBalanceBeforeVoting_) / 100);

        assertEq(uint256(standardGovernor_.state(proposalId2_)), 4); // Succeeded

        // Execute proposal
        standardGovernor_.execute(targets2_, values_, callDatas2_, bytes32(0));
    }
}
