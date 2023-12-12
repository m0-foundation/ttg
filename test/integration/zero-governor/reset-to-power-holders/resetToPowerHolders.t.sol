// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IPowerToken } from "../../../../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { IntegrationBaseSetup, IGovernor, IZeroGovernor } from "../../IntegrationBaseSetup.t.sol";

contract ResetToPowerHolders_IntegrationTest is IntegrationBaseSetup {
    function test_resetToPowerHolders() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        _goToNextEpoch();

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);

        assertEq(uint256(activeState_), 1);

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, 1), _daveWeight);

        (, , , IGovernor.ProposalState succeededState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        IPowerToken nextPowerToken_ = IPowerToken(IPowerTokenDeployer(_registrar.powerTokenDeployer()).nextDeploy());

        address nextStandardGovernor_ = IStandardGovernorDeployer(_registrar.standardGovernorDeployer()).nextDeploy();

        address nextEmergencyGovernor_ = IEmergencyGovernorDeployer(_registrar.emergencyGovernorDeployer())
            .nextDeploy();

        vm.expectEmit();
        emit IZeroGovernor.ResetExecuted(
            address(_powerToken),
            nextStandardGovernor_,
            nextEmergencyGovernor_,
            address(nextPowerToken_)
        );

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

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

        (, , , IGovernor.ProposalState executedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(executedState_), 7);
    }

    function _getProposeParams()
        internal
        view
        returns (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        )
    {
        targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.resetToPowerHolders.selector);

        description_ = "Reset to Power holders";
    }
}
