// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../../../../../lib/common/src/interfaces/IERC20.sol";

import { IPowerToken } from "../../../../../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import {
    ResetIntegrationBaseSetup,
    IBatchGovernor,
    IGovernor,
    IZeroGovernor,
    IEmergencyGovernor,
    IStandardGovernor
} from "../ResetIntegrationBaseSetup.t.sol";

contract ResetToPowerHolders_IntegrationTest is ResetIntegrationBaseSetup {
    function test_resetToPowerHolders() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.resetToPowerHolders.selector);

        string memory description_ = "Reset to Power holders";

        _warpToNextEpoch();

        uint256 voteStart_ = _currentEpoch();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_zeroGovernor));

        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            proposalId_,
            _dave,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            voteStart_ + _zeroGovernor.votingPeriod(),
            description_
        );

        vm.prank(_dave);
        _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);

        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 daveZeroWeight_ = _zeroToken.getVotes(_dave);

        vm.expectEmit();
        emit IGovernor.VoteCast(_dave, proposalId_, yesSupport_, daveZeroWeight_, "");

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), daveZeroWeight_);

        (, , IGovernor.ProposalState succeededState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        IPowerToken nextPowerToken_ = IPowerToken(IPowerTokenDeployer(_registrar.powerTokenDeployer()).nextDeploy());

        address nextStandardGovernor_ = IStandardGovernorDeployer(_registrar.standardGovernorDeployer()).nextDeploy();

        address nextEmergencyGovernor_ = IEmergencyGovernorDeployer(_registrar.emergencyGovernorDeployer())
            .nextDeploy();

        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId_);

        vm.expectEmit();
        emit IZeroGovernor.ResetExecuted(
            address(_powerToken),
            nextStandardGovernor_,
            nextEmergencyGovernor_,
            address(nextPowerToken_)
        );

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(nextPowerToken_.bootstrapEpoch(), _currentEpoch() - 1);

        assertEq(_registrar.powerToken(), address(nextPowerToken_));
        assertEq(_registrar.standardGovernor(), nextStandardGovernor_);
        assertEq(_registrar.emergencyGovernor(), nextEmergencyGovernor_);

        // Epoch 0 is used cause the value doesn't depend on the epoch but is retrieved from the `_balances` of PowerBootstrapToken.
        assertEq(nextPowerToken_.balanceOf(_alice), nextPowerToken_.pastBalanceOf(_alice, 0));
        assertEq(nextPowerToken_.balanceOf(_bob), nextPowerToken_.pastBalanceOf(_bob, 0));
        assertEq(nextPowerToken_.balanceOf(_carol), nextPowerToken_.pastBalanceOf(_carol, 0));
        assertEq(nextPowerToken_.balanceOf(_dave), 0);
        assertEq(nextPowerToken_.balanceOf(_eve), 0);
        assertEq(nextPowerToken_.balanceOf(_frank), 0);

        (, , IGovernor.ProposalState executedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(executedState_), 7);

        assertEq(IStandardGovernor(nextStandardGovernor_).cashToken(), _standardGovernor.cashToken());

        address[] memory powerUsers_ = new address[](3);
        powerUsers_[0] = _dave; // has cash token to pay fee
        powerUsers_[1] = _alice;
        powerUsers_[2] = _bob;

        _revertIfGovernorsAreNotFunctional(
            IStandardGovernor(nextStandardGovernor_),
            IEmergencyGovernor(nextEmergencyGovernor_),
            powerUsers_
        );
    }
}
