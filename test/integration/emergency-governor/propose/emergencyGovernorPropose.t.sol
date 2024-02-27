// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IBatchGovernor } from "../../IntegrationBaseSetup.t.sol";

contract EmergencyGovernorPropose_IntegrationTest is IntegrationBaseSetup {
    // NOTE: Use actors with the following POWER balances:
    // _alice - 55, _bob = 25, _carol =  20

    function test_emergencyGovernorPropose_proposalActiveSucceededExecuted() external {
        uint256 aliceBalance_ = _powerToken.getVotes(_alice);

        // Voting delay is 0 for the emergency governor
        assertEq(_isVotingEpoch(_currentEpoch()), true);
        assertEq(_isTransferEpoch(_currentEpoch()), false);
        assertEq(_emergencyGovernor.votingDelay(), 0);

        _warpToNextEpoch();

        assertEq(_isVotingEpoch(_currentEpoch()), false);
        assertEq(_isTransferEpoch(_currentEpoch()), true);
        assertEq(_emergencyGovernor.votingDelay(), 0);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        uint256 voteStart_ = _currentEpoch();
        uint256 expectedProposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_emergencyGovernor));

        uint256 daveBalanceBefore_ = _cashToken1.balanceOf(_dave);

        vm.prank(_dave);
        uint256 proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(daveBalanceBefore_, _cashToken1.balanceOf(_dave));

        assertEq(proposalId_, expectedProposalId_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active immediately

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);
        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_alice);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        assertEq(_powerToken.balanceOf(_alice), aliceBalance_); // no inflation
        assertEq(_zeroToken.balanceOf(_alice), 0); // no ZERO rewards

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1);

        vm.prank(_carol);
        _emergencyGovernor.castVote(proposalId_, noSupport_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1);

        // Bob allows proposal to meet 80% threshold requirement
        vm.prank(_bob);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 4); // proposal is successful

        vm.prank(_eve);
        _emergencyGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        // Proposal successfully executed
        assertEq(_registrar.listContains(bytes32("MintersList"), _eve), true);
        assertEq(_registrar.listContains(bytes32("MintersList"), _dave), false);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 7); // proposal was executed
    }

    function test_emergencyGovernorPropose_proposalActiveSucceededExpired() external {
        assertEq(_isVotingEpoch(_currentEpoch()), true);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        vm.prank(_dave);
        uint256 proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active immediately

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);
        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_alice);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active

        vm.prank(_carol);
        _emergencyGovernor.castVote(proposalId_, noSupport_);

        // Bob allows proposal to meet 80% threshold requirement
        vm.prank(_bob);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 4); // proposal is successful

        _warpToNextEpoch();
        _warpToNextEpoch();

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 6); // proposal is Expired
    }

    function test_emergencyGovernorPropose_proposalActiveDefeated() external {
        assertEq(_isVotingEpoch(_currentEpoch()), true);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        vm.prank(_dave);
        uint256 proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active immediately

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);
        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_alice);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        vm.warp(block.timestamp + 1);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // still Active

        vm.prank(_carol);
        _emergencyGovernor.castVote(proposalId_, noSupport_);

        vm.warp(block.timestamp + 1);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // still Active

        vm.prank(_bob);
        _emergencyGovernor.castVote(proposalId_, noSupport_);

        vm.warp(block.timestamp + 1);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 3); // proposal is Defeated
    }

    function test_emergencyGovernorPropose_proposalActiveDefeatedFast() external {
        assertEq(_isVotingEpoch(_currentEpoch()), true);

        _warpToNextEpoch();

        vm.prank(_alice);
        _powerToken.delegate(_bob);

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        vm.prank(_dave);
        uint256 proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active immediately

        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_bob);
        _emergencyGovernor.castVote(proposalId_, noSupport_);

        vm.warp(block.timestamp + 1);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 3); // proposal is Defeated
    }

    function test_emergencyGovernorPropose_bootstrapVotes_certora_H01() public {
        _warpToNextTransferEpoch();

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getRemoveFromAndAddToListProposeParams();

        assertEq(_powerToken.getPastVotes(_alice, _currentEpoch() - 1), 5500);
        assertEq(_powerToken.getPastVotes(_bob, _currentEpoch() - 1), 2500);
        assertEq(_powerToken.getPastVotes(_carol, _currentEpoch() - 1), 2000);

        vm.prank(_alice);
        _powerToken.transfer(_bob, 0);

        vm.prank(_bob);
        _powerToken.transfer(_carol, 0);

        assertEq(_powerToken.getPastVotes(_alice, _currentEpoch() - 1), 5500);
        assertEq(_powerToken.getPastVotes(_bob, _currentEpoch() - 1), 2500);
        assertEq(_powerToken.getPastVotes(_carol, _currentEpoch() - 1), 2000);

        vm.prank(_dave);
        uint256 proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 1); // Active immediately

        (, , , uint256 noVotes, uint256 yesVotes, , ) = _emergencyGovernor.getProposal(proposalId_);

        vm.prank(_alice);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        vm.prank(_bob);
        _emergencyGovernor.castVote(proposalId_, yesSupport_);

        (, , , noVotes, yesVotes, , ) = _emergencyGovernor.getProposal(proposalId_);

        assertEq(uint256(_emergencyGovernor.state(proposalId_)), 4);
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
        targets_[0] = address(_emergencyGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            _emergencyGovernor.removeFromAndAddToList.selector,
            bytes32("MintersList"),
            _dave,
            _eve
        );

        description_ = "Emergency remove Dave from MintersList and add Eve";
    }
}
