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

        _warpToNextVoteEpoch();

        (, , , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _warpToNextEpoch();

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

        _warpToNextVoteEpoch();

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

        _warpToNextVoteEpoch();

        (, , , IGovernor.ProposalState succeededState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        _warpToNextEpoch();

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

        _warpToNextVoteEpoch();

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

        _warpToNextEpoch();

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

    function test_standardGovernorPropose_proposalLifecycle() external {
        uint256 aliceBalance_ = (55 * _powerToken.INITIAL_SUPPLY()) / 100;
        uint256 aliceVotingPower_ = aliceBalance_;

        uint256 bobBalance_ = (25 * _powerToken.INITIAL_SUPPLY()) / 100;
        uint256 bobVotingPower_ = bobBalance_;

        uint256 carolBalance_ = (20 * _powerToken.INITIAL_SUPPLY()) / 100;
        uint256 carolVotingPower_ = carolBalance_;

        // Starting POWER balances and voting powers of actors
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);
        assertEq(_powerToken.getVotes(_alice), aliceVotingPower_);

        assertEq(_powerToken.balanceOf(_bob), bobBalance_);
        assertEq(_powerToken.getVotes(_bob), bobVotingPower_);

        assertEq(_powerToken.balanceOf(_carol), carolBalance_);
        assertEq(_powerToken.getVotes(_carol), carolVotingPower_);

        // 2 epochs delay if proposal is created during a voting epoch.
        _warpToNextVoteEpoch();

        assertTrue(_isVotingEpoch(_currentEpoch()));
        assertEq(_standardGovernor.votingDelay(), 2);

        // 1 epoch delay if proposal is created during a transfer epoch.
        _warpToNextTransferEpoch();

        assertTrue(_isTransferEpoch(_currentEpoch()));
        assertEq(_standardGovernor.votingDelay(), 1);

        (address[] memory targets_, , bytes[] memory callDatas_, ) = _getProposeParams();

        vm.prank(_dave);
        uint256 proposalId_ = _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        uint256 proposalSnapshot_ = _standardGovernor.proposalSnapshot(proposalId_);

        assertEq(proposalSnapshot_, _currentEpoch());
        assertEq(_standardGovernor.proposalDeadline(proposalId_), _currentEpoch() + 1);
        assertEq(uint256(_standardGovernor.state(proposalId_)), 0);
        assertEq(_standardGovernor.proposalProposer(proposalId_), _dave);

        // Alice delegates her voting power to Bob.
        vm.prank(_alice);
        _powerToken.delegate(_bob);

        bobVotingPower_ += aliceVotingPower_;
        aliceVotingPower_ = 0;

        _warpToNextVoteEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        assertEq(_powerToken.getPastVotes(_alice, proposalSnapshot_), aliceVotingPower_);
        assertEq(_powerToken.getPastVotes(_bob, proposalSnapshot_), bobVotingPower_);
        assertEq(_powerToken.getPastVotes(_carol, proposalSnapshot_), carolVotingPower_);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), aliceVotingPower_);

        // Alice's POWER balance and voting power are not inflated since Alice has no voting power.
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);
        assertEq(_powerToken.getVotes(_alice), aliceVotingPower_);

        // Alice received no ZERO rewards
        assertEq(_zeroToken.balanceOf(_alice), (1_000e6 * aliceVotingPower_) / 100);

        vm.prank(_bob);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), bobVotingPower_);

        // Alice and Bob's POWER balance are inflated since Bob has voting power.
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_bob), _getInflatedAmount(bobBalance_));

        // Bob's POWER voting power is inflated.
        assertEq(_powerToken.getVotes(_bob), _getInflatedAmount(bobVotingPower_));

        // Bob received ZERO rewards since he has 80% voting power as a delegatee of alice and self-delegatee.
        assertEq(_zeroToken.balanceOf(_bob), (1_000e6 * 80) / 100);

        vm.prank(_carol);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.No)), carolVotingPower_);

        // Carol's POWER balance and voting power are inflated since Carol has voting power.
        assertEq(_powerToken.balanceOf(_carol), _getInflatedAmount(carolBalance_));
        assertEq(_powerToken.getVotes(_carol), _getInflatedAmount(carolVotingPower_));

        // Carol received ZERO rewards since he has 20% voting power as self-delegatee.
        assertEq(_zeroToken.balanceOf(_carol), (1_000e6 * 20) / 100);

        assertTrue(_standardGovernor.hasVotedOnAllProposals(_alice, _currentEpoch()));
        assertTrue(_standardGovernor.hasVotedOnAllProposals(_bob, _currentEpoch()));
        assertTrue(_standardGovernor.hasVotedOnAllProposals(_carol, _currentEpoch()));

        (, , , , uint256 noVotes_, uint256 yesVotes_, ) = _standardGovernor.getProposal(proposalId_);
        assertEq(yesVotes_, aliceVotingPower_ + bobVotingPower_);
        assertEq(noVotes_, carolVotingPower_);
        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertTrue(_isTransferEpoch(_currentEpoch()));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));

        assertEq(
            _powerToken.getVotes(_alice) + _powerToken.getVotes(_bob) + _powerToken.getVotes(_carol),
            _powerToken.balanceOf(_alice) + _powerToken.balanceOf(_bob) + _powerToken.balanceOf(_carol)
        );
    }

    function _getInflatedAmount(uint256 amount_) internal view returns (uint256 inflatedAmount_) {
        return amount_ + (amount_ * _powerToken.participationInflation()) / 10_000;
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
