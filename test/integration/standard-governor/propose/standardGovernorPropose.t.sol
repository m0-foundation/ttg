// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../../../../lib/common/src/interfaces/IERC20.sol";

import { IERC5805 } from "../../../../src/abstract/interfaces/IERC5805.sol";
import { IPowerTokenDeployer } from "../../../../src/interfaces/IPowerTokenDeployer.sol";
import { IStandardGovernorDeployer } from "../../../../src/interfaces/IStandardGovernorDeployer.sol";
import { IEmergencyGovernorDeployer } from "../../../../src/interfaces/IEmergencyGovernorDeployer.sol";

import {
    IntegrationBaseSetup,
    IBatchGovernor,
    IGovernor,
    IPowerToken,
    IRegistrar,
    IStandardGovernor
} from "../../IntegrationBaseSetup.t.sol";

contract StandardGovernorPropose_IntegrationTest is IntegrationBaseSetup {
    function test_standardGovernorPropose_proposalPendingActiveDefeated() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        uint256 voteStart_ = _currentEpoch() + _standardGovernor.votingDelay();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_standardGovernor));

        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            proposalId_,
            _dave,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            voteStart_ + _standardGovernor.votingPeriod(),
            description_
        );

        vm.expectEmit();
        emit IPowerToken.TargetSupplyInflated(voteStart_, _getNextTargetSupply(_powerToken));

        vm.expectEmit();
        emit IERC20.Approval(_dave, address(_standardGovernor), _cashToken1MaxAmount - _standardProposalFee);

        vm.expectEmit();
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _goToNextEpoch();

        (, , , IGovernor.ProposalState defeatedState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(defeatedState_), 3);
    }

    function test_standardGovernorPropose_proposalPendingActiveSucceededExpired() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        uint256 voteStart_ = _currentEpoch() + _standardGovernor.votingDelay();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_standardGovernor));

        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            proposalId_,
            _dave,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            voteStart_ + _standardGovernor.votingPeriod(),
            description_
        );

        vm.expectEmit();
        emit IPowerToken.TargetSupplyInflated(voteStart_, _getNextTargetSupply(_powerToken));

        vm.expectEmit();
        emit IERC20.Approval(_dave, address(_standardGovernor), _cashToken1MaxAmount - _standardProposalFee);

        vm.expectEmit();
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, yesSupport_, _alicePowerWeight, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, voteStart_);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, _alicePowerWeight);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(
            _alice,
            _alicePowerWeight,
            _alicePowerWeight + _getInflationReward(_powerToken, _alicePowerWeight)
        );

        uint256 zeroTokenReward_ = _getZeroTokenReward(_standardGovernor, _alicePowerWeight, _powerToken, START_EPOCH);

        vm.expectEmit(address(_zeroToken));
        emit IERC20.Transfer(address(0), _alice, zeroTokenReward_);

        vm.expectEmit(address(_zeroToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, zeroTokenReward_);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, yesSupport_);

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState succeededState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        _goToNextEpoch();

        (, , , IGovernor.ProposalState expiredState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);
    }

    function test_standardGovernorPropose_proposalPendingActiveSucceededExecuted() external {
        vm.prank(address(_standardGovernor));
        _registrar.addToList("MintersList", _dave);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        uint256 voteStart_ = _currentEpoch() + _standardGovernor.votingDelay();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_standardGovernor));

        vm.expectEmit();
        emit IGovernor.ProposalCreated(
            proposalId_,
            _dave,
            targets_,
            values_,
            new string[](targets_.length),
            callDatas_,
            voteStart_,
            voteStart_ + _standardGovernor.votingPeriod(),
            description_
        );

        vm.expectEmit();
        emit IPowerToken.TargetSupplyInflated(voteStart_, _getNextTargetSupply(_powerToken));

        vm.expectEmit();
        emit IERC20.Approval(_dave, address(_standardGovernor), _cashToken1MaxAmount - _standardProposalFee);

        vm.expectEmit();
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);

        _goToNextVoteEpoch();

        (, , , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, yesSupport_, _alicePowerWeight, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, voteStart_);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, _alicePowerWeight);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(
            _alice,
            _alicePowerWeight,
            _alicePowerWeight + _getInflationReward(_powerToken, _alicePowerWeight)
        );

        uint256 zeroTokenReward_ = _getZeroTokenReward(_standardGovernor, _alicePowerWeight, _powerToken, START_EPOCH);

        vm.expectEmit(address(_zeroToken));
        emit IERC20.Transfer(address(0), _alice, zeroTokenReward_);

        vm.expectEmit(address(_zeroToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, zeroTokenReward_);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, yesSupport_);

        _goToNextEpoch();

        (, , , IGovernor.ProposalState succeededState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId_);

        vm.expectEmit();
        emit IRegistrar.AddressRemovedFromList("MintersList", _dave);

        vm.expectEmit();
        emit IRegistrar.AddressAddedToList("MintersList", _eve);

        vm.expectEmit(address(_cashToken1));
        emit IERC20.Transfer(address(_standardGovernor), _dave, _standardProposalFee);

        _standardGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertFalse(_registrar.listContains("MintersList", _dave));
        assertTrue(_registrar.listContains("MintersList", _eve));

        (, , , IGovernor.ProposalState executedState_, , , ) = _standardGovernor.getProposal(proposalId_);
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
        targets_[0] = address(_standardGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            _standardGovernor.removeFromAndAddToList.selector,
            bytes32("MintersList"),
            _dave,
            _eve
        );

        description_ = "Remove Dave from MintersList and add Eve";
    }
}
