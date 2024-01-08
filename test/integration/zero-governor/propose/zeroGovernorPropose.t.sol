// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IGovernor, IBatchGovernor } from "../../IntegrationBaseSetup.t.sol";

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

        (, , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _jumpEpochs(2);

        vm.mockCall(address(_zeroToken), abi.encodeWithSelector(_zeroToken.balanceOf.selector, _dave), abi.encode(0));

        vm.mockCall(
            address(_zeroToken),
            abi.encodeWithSelector(_zeroToken.pastTotalSupply.selector, START_EPOCH),
            abi.encode(0)
        );

        (, , IGovernor.ProposalState expiredState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
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

        (, , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        _jumpEpochs(2);

        (, , IGovernor.ProposalState expiredState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(expiredState_), 6);
    }

    function test_zeroGovernorPropose_proposalActiveDefeated() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        _warpToNextEpoch();

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

        (, , IGovernor.ProposalState activeState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(activeState_), 1);

        uint256 eveZeroWeight_ = _zeroToken.getVotes(_eve);

        vm.prank(_eve);
        assertEq(_zeroGovernor.castVote(proposalId_, 1), eveZeroWeight_);

        _jumpEpochs(3);

        (, , IGovernor.ProposalState defeatedState_, , , , ) = _zeroGovernor.getProposal(proposalId_);
        assertEq(uint256(defeatedState_), 3);
    }

    function test_zeroGovernorPropose_proposalActiveSucceededExecuted() external {
        _warpToNextEpoch();

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        vm.prank(_eve);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // Active immediately

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 daveZeroWeight_ = _zeroToken.getVotes(_dave);

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), daveZeroWeight_);

        (, , , uint256 noVotes_, uint256 yesVotes_, , uint256 thresholdRatio_) = _zeroGovernor.getProposal(proposalId_);
        assertEq(noVotes_, 0);
        assertEq(yesVotes_, daveZeroWeight_);
        assertEq(thresholdRatio_, 6000);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // proposal has Succeeded

        vm.prank(_eve);
        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 7); // proposal was Executed
    }

    function test_zeroGovernorPropose_proposalActiveSucceededExpired() external {
        _warpToNextEpoch();

        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getProposeParams();

        vm.prank(_eve);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // Active immediately

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 eveZeroWeight_ = _zeroToken.getVotes(_eve);

        vm.prank(_eve);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), eveZeroWeight_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // proposal is Active

        uint256 frankZeroWeight_ = _zeroToken.getVotes(_frank);

        vm.prank(_frank);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), frankZeroWeight_);

        // Still not enough votes to meet 60% threshold
        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // proposal is Active

        uint256 daveZeroWeight_ = _zeroToken.getVotes(_dave);

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), daveZeroWeight_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // proposal has Succeeded

        _jumpEpochs(1);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // proposal has Succeeded

        _jumpEpochs(1);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 6); // proposal has Expired
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
