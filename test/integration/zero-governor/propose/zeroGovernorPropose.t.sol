// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IPowerToken } from "../../../../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { IntegrationBaseSetup, IGovernor } from "../../IntegrationBaseSetup.t.sol";

contract ZeroGovernorPropose_IntegrationTest is IntegrationBaseSetup {
    function test_zeroGovernorPropose_totalSupplyZero() external {
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

    function test_zeroGovernorPropose_proposalActiveExpired() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

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

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState expiredState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);
    }

    function test_zeroGovernorPropose_proposalActiveDefeated() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        _goToNextEpoch();

        uint256 voteStart_ = _currentEpoch();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_zeroGovernor));

        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            proposalId_,
            _eve,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            voteStart_ + _zeroGovernor.votingPeriod(),
            description_
        );

        vm.prank(_eve);
        _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        vm.prank(_eve);
        assertEq(_zeroGovernor.castVote(proposalId_, 1), _eveZeroWeight);

        _goToNextTransferEpoch();

        (, , , IGovernor.ProposalState defeatedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(defeatedState_), 3);
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
