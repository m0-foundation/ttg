// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../../../../lib/common/src/interfaces/IERC20.sol";

import { IERC5805 } from "../../../../src/abstract/interfaces/IERC5805.sol";

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
        ) = _getRemoveFromAndAddToListProposeParams();

        uint16 voteStart_ = _currentEpoch() + uint16(_standardGovernor.votingDelay());
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
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);
        assertEq(uint256(_standardGovernor.state(proposalId_)), 0);

        _warpToNextVoteEpoch();

        (, , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);
        assertEq(uint256(_standardGovernor.state(proposalId_)), 1);

        _warpToNextEpoch();

        (, , IGovernor.ProposalState defeatedState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(defeatedState_), 3);
        assertEq(uint256(_standardGovernor.state(proposalId_)), 3);
    }

    function test_standardGovernorPropose_proposalPendingActiveSucceededExpired() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        uint16 voteStart_ = _currentEpoch() + uint16(_standardGovernor.votingDelay());
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
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);

        _warpToNextVoteEpoch();

        (, , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 alicePowerWeight_ = _powerToken.getVotes(_alice);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, yesSupport_, alicePowerWeight_, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, voteStart_);

        // Due to bootstrap
        vm.expectEmit(address(_powerToken));
        emit IERC20.Transfer(_powerToken.bootstrapToken(), _alice, alicePowerWeight_);

        // Due to bootstrap
        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, alicePowerWeight_);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, alicePowerWeight_, _getInflatedAmount(alicePowerWeight_));

        uint256 zeroTokenReward_ = _getZeroTokenReward(_standardGovernor, alicePowerWeight_, _powerToken, START_EPOCH);

        vm.expectEmit(address(_zeroToken));
        emit IERC20.Transfer(address(0), _alice, zeroTokenReward_);

        vm.expectEmit(address(_zeroToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, zeroTokenReward_);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, yesSupport_);

        _warpToNextEpoch();

        (, , IGovernor.ProposalState succeededState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(succeededState_), 4);

        _warpToNextEpoch();

        (, , IGovernor.ProposalState expiredState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);

        uint256 vaultCashBalanceBefore_ = _cashToken1.balanceOf(address(_vault));
        _standardGovernor.sendProposalFeeToVault(proposalId_);
        assertEq(_cashToken1.balanceOf(address(_vault)), vaultCashBalanceBefore_ + _standardProposalFee);
    }

    function test_standardGovernorPropose_proposalPendingActiveSucceededExecuted() external {
        vm.prank(address(_standardGovernor));
        _registrar.addToList("MintersList", _dave);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        uint16 voteStart_ = _currentEpoch() + uint16(_standardGovernor.votingDelay());
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
        emit IERC20.Transfer(_dave, address(_standardGovernor), _standardProposalFee);

        vm.prank(_dave);
        _standardGovernor.propose(targets_, values_, callDatas_, description_);

        (, , IGovernor.ProposalState pendingState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(pendingState_), 0);

        _warpToNextVoteEpoch();

        (, , IGovernor.ProposalState activeState_, , , ) = _standardGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 alicePowerWeight_ = _powerToken.getVotes(_alice);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, yesSupport_, alicePowerWeight_, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, voteStart_);

        // Due to bootstrap
        vm.expectEmit(address(_powerToken));
        emit IERC20.Transfer(_powerToken.bootstrapToken(), _alice, alicePowerWeight_);

        // Due to bootstrap
        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, alicePowerWeight_);

        vm.expectEmit(address(_powerToken));
        emit IERC5805.DelegateVotesChanged(_alice, alicePowerWeight_, _getInflatedAmount(alicePowerWeight_));

        uint256 zeroTokenReward_ = _getZeroTokenReward(_standardGovernor, alicePowerWeight_, _powerToken, START_EPOCH);

        vm.expectEmit(address(_zeroToken));
        emit IERC20.Transfer(address(0), _alice, zeroTokenReward_);

        vm.expectEmit(address(_zeroToken));
        emit IERC5805.DelegateVotesChanged(_alice, 0, zeroTokenReward_);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, yesSupport_);

        _warpToNextEpoch();

        (, , IGovernor.ProposalState succeededState_, , , ) = _standardGovernor.getProposal(proposalId_);
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

        (, , IGovernor.ProposalState executedState_, , , ) = _standardGovernor.getProposal(proposalId_);
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
        _warpToNextEpoch();

        assertTrue(_isTransferEpoch(_currentEpoch()));
        assertEq(_standardGovernor.votingDelay(), 1);

        (address[] memory targets_, , bytes[] memory callDatas_, ) = _getRemoveFromAndAddToListProposeParams();

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

        _warpToNextEpoch();

        assertTrue(_isVotingEpoch(_currentEpoch()));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        assertEq(_powerToken.getPastVotes(_alice, proposalSnapshot_), aliceVotingPower_);
        assertEq(_powerToken.getPastVotes(_bob, proposalSnapshot_), bobVotingPower_);
        assertEq(_powerToken.getPastVotes(_carol, proposalSnapshot_), carolVotingPower_);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), aliceVotingPower_);

        assertTrue(_standardGovernor.hasVotedOnAllProposals(_alice, _currentEpoch()));
        assertFalse(_standardGovernor.hasVotedOnAllProposals(_bob, _currentEpoch()));
        assertFalse(_standardGovernor.hasVotedOnAllProposals(_carol, _currentEpoch()));

        // Alice's POWER voting power is not inflated since Alice has no voting power.
        assertEq(_powerToken.getVotes(_alice), aliceVotingPower_);

        // Alice received no ZERO rewards
        assertEq(_zeroToken.balanceOf(_alice), (1_000e6 * aliceVotingPower_) / 100);

        (, , , uint256 noVotes_, uint256 yesVotes_, ) = _standardGovernor.getProposal(proposalId_);
        assertEq(yesVotes_, 0);
        assertEq(noVotes_, 0);
        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertTrue(_isTransferEpoch(_currentEpoch()));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Defeated));

        // Alice's POWER balance is not inflated since Alice has no voting power.
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);

        vm.prank(_dave);
        proposalId_ = _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        proposalSnapshot_ = _standardGovernor.proposalSnapshot(proposalId_);

        assertEq(proposalSnapshot_, _currentEpoch());
        assertEq(_standardGovernor.proposalDeadline(proposalId_), _currentEpoch() + 1);
        assertEq(uint256(_standardGovernor.state(proposalId_)), 0);
        assertEq(_standardGovernor.proposalProposer(proposalId_), _dave);

        _warpToNextEpoch();

        assertTrue(_isVotingEpoch(_currentEpoch()));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        assertEq(_powerToken.getPastVotes(_alice, proposalSnapshot_), aliceVotingPower_);
        assertEq(_powerToken.getPastVotes(_bob, proposalSnapshot_), bobVotingPower_);
        assertEq(_powerToken.getPastVotes(_carol, proposalSnapshot_), carolVotingPower_);

        vm.prank(_bob);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), bobVotingPower_);

        vm.prank(_carol);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.No)), carolVotingPower_);

        assertFalse(_standardGovernor.hasVotedOnAllProposals(_alice, _currentEpoch()));
        assertTrue(_standardGovernor.hasVotedOnAllProposals(_bob, _currentEpoch()));
        assertTrue(_standardGovernor.hasVotedOnAllProposals(_carol, _currentEpoch()));

        // Alice's POWER voting power is still entirely delegated to Bob, so it is not changed.
        assertEq(_powerToken.getVotes(_alice), 0);

        // Bob's POWER voting power is inflated.
        assertEq(_powerToken.getVotes(_bob), _getInflatedAmount(bobVotingPower_));

        // Bob received ZERO rewards since he has 80% voting power as a delegatee of alice and self-delegatee.
        assertEq(_zeroToken.balanceOf(_bob), (5_000_000e6 * 80) / 100);

        // Carol's POWER voting power is inflated since Carol has voting power.
        assertEq(_powerToken.getVotes(_carol), _getInflatedAmount(carolVotingPower_));

        // Carol received ZERO rewards since he has 20% voting power as self-delegatee.
        assertEq(_zeroToken.balanceOf(_carol), (5_000_000e6 * 20) / 100);

        (, , , noVotes_, yesVotes_, ) = _standardGovernor.getProposal(proposalId_);
        assertEq(yesVotes_, bobVotingPower_);
        assertEq(noVotes_, carolVotingPower_);
        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertTrue(_isTransferEpoch(_currentEpoch()));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));

        // Alice and Bob's POWER balance are inflated since Bob has voting power.
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_bob), _getInflatedAmount(bobBalance_));

        // Carol's POWER balance is inflated since Carol has voting power.
        assertEq(_powerToken.balanceOf(_carol), _getInflatedAmount(carolBalance_));

        _warpToNextEpoch();

        assertTrue(_isVotingEpoch(_currentEpoch()));

        assertEq(
            _powerToken.getVotes(_alice) + _powerToken.getVotes(_bob) + _powerToken.getVotes(_carol),
            _powerToken.balanceOf(_alice) + _powerToken.balanceOf(_bob) + _powerToken.balanceOf(_carol)
        );
    }

    function test_standardGovernorPropose_changeProposalFee() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getSetStandardProposalFeeProposeParams();

        uint256 cashTokenBalanceBeforePropose_ = _cashToken1.balanceOf(_dave);

        vm.prank(_dave);
        uint256 proposalId_ = _standardGovernor.propose(targets_, values_, callDatas_, description_);

        // Dave's balance is decreased by the proposal fee
        assertEq(_cashToken1.balanceOf(_dave), cashTokenBalanceBeforePropose_ - _standardProposalFee);

        _warpToNextVoteEpoch();

        assertEq(_standardGovernor.proposalFee(), _standardProposalFee);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        _warpToNextEpoch();

        (
            address[] memory targets1_,
            uint256[] memory values1_,
            bytes[] memory callDatas1_,
            string memory description1_
        ) = _getRemoveFromAndAddToListProposeParams();

        uint256 cashTokenBalanceBeforePropose1_ = _cashToken1.balanceOf(_frank);

        vm.prank(_frank);
        _standardGovernor.propose(targets1_, values1_, callDatas1_, description1_);

        // Frank's balance is decreased by the proposal fee
        assertEq(_cashToken1.balanceOf(_frank), cashTokenBalanceBeforePropose1_ - _standardProposalFee);

        _standardGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        // Proposal fee is updated
        assertEq(_standardGovernor.proposalFee(), 2 * _standardProposalFee);

        // Proposal fee was refunded to Dave
        assertEq(_cashToken1.balanceOf(_dave), cashTokenBalanceBeforePropose_);

        (
            address[] memory targets2_,
            uint256[] memory values2_,
            bytes[] memory callDatas2_,
            string memory description2_
        ) = _getSetKeyProposeParams();

        uint256 cashTokenBalanceBeforePropose2_ = _cashToken1.balanceOf(_eve);

        vm.prank(_eve);
        _standardGovernor.propose(targets2_, values2_, callDatas2_, description2_);

        // Eve's balance is decreased by the updated proposal fee
        assertEq(_cashToken1.balanceOf(_eve), cashTokenBalanceBeforePropose2_ - 2 * _standardProposalFee);
    }

    function _getInflatedAmount(uint256 amount_) internal view returns (uint256 inflatedAmount_) {
        return amount_ + (amount_ * _powerToken.participationInflation()) / 10_000;
    }

    function _getRemoveFromAndAddToListProposeParams()
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

    function _getSetKeyProposeParams()
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
            _standardGovernor.setKey.selector,
            bytes32("TEST_KEY"),
            bytes32("TEST_VALUE")
        );

        description_ = "Set TEST_KEY to TEST_VALUE";
    }

    function _getSetStandardProposalFeeProposeParams()
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
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 2 * _standardProposalFee);

        description_ = "Double standard proposal fee ";
    }
}
