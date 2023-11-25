// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";

import { DualGovernorHarness } from "./utils/DualGovernorHarness.sol";
import { MockPowerToken, MockZeroToken } from "./utils/Mocks.sol";

// TODO: test_ProposalShouldChangeStatesCorrectly
// TODO: test_CanVoteOnMultipleProposals
// TODO: test_UserVoteInflationAfterVotingOnAllProposals
// TODO: test_DelegateValueRewardsAfterVotingOnAllProposals

contract DualGovernorTests is Test {
    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
    address internal _cashToken = makeAddr("cashToken");
    address internal _vault = makeAddr("vault");
    address internal _registrar = makeAddr("registrar");

    uint256 internal _powerThresholdRatio = _ONE / 40;
    uint256 internal _zeroThresholdRatio = _ONE / 60;

    DualGovernorHarness internal _dualGovernor;
    MockPowerToken internal _powerToken;
    MockZeroToken internal _zeroToken;

    function setUp() external {
        _powerToken = new MockPowerToken();
        _zeroToken = new MockZeroToken();

        _dualGovernor = new DualGovernorHarness(
            _registrar,
            _cashToken,
            address(_powerToken),
            address(_zeroToken),
            _vault,
            5,
            1_000,
            uint16(_powerThresholdRatio),
            uint16(_zeroThresholdRatio)
        );
    }

    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _dualGovernor.clock();

        _dualGovernor.setProposal(
            proposalId_,
            IDualGovernor.ProposalType.Standard,
            currentEpoch + 1,
            currentEpoch + 10,
            0
        );

        vm.expectRevert(
            abi.encodeWithSelector(IDualGovernor.ProposalNotActive.selector, IGovernor.ProposalState.Pending)
        );

        _dualGovernor.castVote(proposalId_, uint8(IDualGovernor.VoteType.Yes));
    }

    function test_castVote_votedOnAllStandardProposals() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _dualGovernor.clock();

        _dualGovernor.setProposal(
            proposalId_,
            IDualGovernor.ProposalType.Standard,
            currentEpoch,
            currentEpoch + 1,
            _powerThresholdRatio
        );

        _powerToken.setVotePower(1);
        _powerToken.setTotalSupplyAt(1);
        // TODO: Set  _numberOfProposals for proper calls

        vm.prank(_alice);
        _dualGovernor.castVote(proposalId_, uint8(IDualGovernor.VoteType.Yes));
    }

    function test_propose_invalidTargetsLength() external {
        vm.expectRevert(IDualGovernor.InvalidTargetsLength.selector);
        _dualGovernor.propose(new address[](2), new uint256[](0), new bytes[](0), "");
    }

    function test_propose_invalidTarget() external {
        vm.expectRevert(IDualGovernor.InvalidTarget.selector);
        _dualGovernor.propose(new address[](1), new uint256[](0), new bytes[](0), "");
    }

    function test_propose_invalidValuesLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        vm.expectRevert(IDualGovernor.InvalidValuesLength.selector);
        _dualGovernor.propose(targets_, new uint256[](2), new bytes[](0), "");
    }

    function test_propose_invalidValue() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 1;

        vm.expectRevert(IDualGovernor.InvalidValue.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](0), "");
    }

    function test_propose_invalidCalldatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        vm.expectRevert(IDualGovernor.InvalidCalldatasLength.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](2), "");
    }

    function test_propose_proposalExists() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        _dualGovernor.setProposal(
            _dualGovernor.hashProposal(targets_, values_, new bytes[](1), keccak256(bytes(""))),
            IDualGovernor.ProposalType.Standard,
            1,
            1,
            0
        );

        vm.expectRevert(IDualGovernor.ProposalExists.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](1), "");
    }

    function test_propose_invalidProposalType() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        vm.expectRevert(IDualGovernor.InvalidProposalType.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](1), "");
    }

    // TODO: Thee are multiple reasons why a proposal is not successful or not yet successful.
    function test_execute_proposalNotSuccessful() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory calldatas_ = new bytes[](1);

        bytes32 descriptionHash_ = keccak256(bytes(""));

        uint256 proposalId_ = _dualGovernor.hashProposal(targets_, values_, calldatas_, descriptionHash_);
        uint256 currentEpoch = _dualGovernor.clock();

        _dualGovernor.setProposal(
            proposalId_,
            IDualGovernor.ProposalType.Standard,
            currentEpoch - 1,
            currentEpoch - 1,
            _powerThresholdRatio
        );

        vm.expectRevert(IDualGovernor.ProposalNotSuccessful.selector);
        _dualGovernor.execute(targets_, values_, calldatas_, descriptionHash_);
    }
}
