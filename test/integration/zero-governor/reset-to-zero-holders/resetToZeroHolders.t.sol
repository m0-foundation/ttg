// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IPowerToken } from "../../../../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { IntegrationBaseSetup, IGovernor } from "../../IntegrationBaseSetup.t.sol";

contract ResetToZeroHolders_IntegrationTest is IntegrationBaseSetup {
    function test_resetToZeroHolders_totalSupplyZero() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        vm.mockCall(address(_zeroToken), abi.encodeWithSelector(_zeroToken.balanceOf.selector, _dave), abi.encode(0));

        vm.mockCall(
            address(_zeroToken),
            abi.encodeWithSelector(_zeroToken.pastTotalSupply.selector, START_EPOCH),
            abi.encode(0)
        );

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _goToNextVoteEpoch();

        vm.mockCall(address(_zeroToken), abi.encodeWithSelector(_zeroToken.balanceOf.selector, _dave), abi.encode(0));

        vm.mockCall(
            address(_zeroToken),
            abi.encodeWithSelector(_zeroToken.pastTotalSupply.selector, START_EPOCH),
            abi.encode(0)
        );

        (, , , IGovernor.ProposalState expiredState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);
    }

    function test_resetToZeroHolders_proposalActiveExpired() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState expiredState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);
    }

    function test_resetToZeroHolders_proposalActiveDefeated() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        _goToNextEpoch();

        vm.prank(_eve);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        vm.prank(_eve);
        assertEq(_zeroGovernor.castVote(proposalId_, 1), _eveWeight);

        _goToNextTransferEpoch();

        (, , , IGovernor.ProposalState defeatedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(defeatedState_), 3);
    }

    function test_resetToZeroHolders_proposalActiveSucceededExecute() external {
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

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(_registrar.powerToken(), address(nextPowerToken_));
        assertEq(_registrar.standardGovernor(), nextStandardGovernor_);
        assertEq(_registrar.emergencyGovernor(), nextEmergencyGovernor_);

        assertEq(nextPowerToken_.balanceOf(_alice), 0);
        assertEq(nextPowerToken_.balanceOf(_bob), 0);
        assertEq(nextPowerToken_.balanceOf(_carol), 0);
        assertEq(nextPowerToken_.balanceOf(_dave), nextPowerToken_.pastBalanceOf(_dave, START_EPOCH));
        assertEq(nextPowerToken_.balanceOf(_eve), nextPowerToken_.pastBalanceOf(_eve, START_EPOCH));
        assertEq(nextPowerToken_.balanceOf(_frank), nextPowerToken_.pastBalanceOf(_frank, START_EPOCH));
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
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.resetToZeroHolders.selector);

        description_ = "Reset to Zero holders";
    }
}
