// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IPowerToken } from "../../../../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { IntegrationBaseSetup, IGovernor, IStandardGovernor, IThresholdGovernor, IZeroGovernor } from "../../IntegrationBaseSetup.t.sol";

contract SetZeroProposalThresholdRatio_IntegrationTest is IntegrationBaseSetup {
    function test_setZeroProposalThresholdRatio() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);
        uint16 newZeroProposalThresholdRatio_ = 7_000; // 70%

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            _zeroGovernor.setZeroProposalThresholdRatio.selector,
            newZeroProposalThresholdRatio_
        );

        string memory description_ = "Set Zero Proposal threshold ratio";

        _goToNextEpoch();

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

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);

        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = 1;

        vm.expectEmit();
        emit IGovernor.VoteCast(_dave, proposalId_, yesSupport_, _daveWeight, "");

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), _daveWeight);

        (, , , IGovernor.ProposalState succeededState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId_);

        vm.expectEmit();
        emit IThresholdGovernor.ThresholdRatioSet(newZeroProposalThresholdRatio_);

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(_zeroGovernor.thresholdRatio(), newZeroProposalThresholdRatio_);

        (, , , IGovernor.ProposalState executedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(executedState_), 7);
    }
}
