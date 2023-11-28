// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";

import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";

import { StandardGovernorHarness } from "./utils/StandardGovernorHarness.sol";
import { MockERC20, MockPowerToken, MockRegistrar, MockZeroToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_ProposalShouldChangeStatesCorrectly
// TODO: test_CanVoteOnMultipleProposals
// TODO: test_state matrix.

contract StandardGovernorTests is TestUtils {
    event CashTokenSet(address indexed cashToken_);
    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 proposalFee);
    event ProposalFeeSet(uint256 proposalFee_);

    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _vault = makeAddr("vault");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    uint256 internal _maxTotalZeroRewardPerActiveEpoch = 1_000;
    uint256 internal _proposalFee = 5;

    StandardGovernorHarness internal _governor;

    MockERC20 internal _cashToken;
    MockPowerToken internal _powerToken;
    MockRegistrar internal _registrar;
    MockZeroToken internal _zeroToken;

    function setUp() external {
        _cashToken = new MockERC20();
        _powerToken = new MockPowerToken();
        _zeroToken = new MockZeroToken();
        _registrar = new MockRegistrar();

        _governor = new StandardGovernorHarness(
            address(_registrar),
            address(_powerToken),
            _emergencyGovernor,
            _zeroGovernor,
            address(_zeroToken),
            address(_cashToken),
            _vault,
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    // TODO: A portion of this can be duplicated into a `BatchGovernor.t.sol -> test_initialState`.
    function test_initialState() external {
        assertEq(_governor.emergencyGovernor(), address(_emergencyGovernor));
        assertEq(_governor.vault(), _vault);
        assertEq(_governor.zeroGovernor(), address(_zeroGovernor));
        assertEq(_governor.zeroToken(), address(_zeroToken));
        assertEq(_governor.maxTotalZeroRewardPerActiveEpoch(), _maxTotalZeroRewardPerActiveEpoch);
        assertEq(_governor.cashToken(), address(_cashToken));
        assertEq(_governor.proposalFee(), _proposalFee);
        assertEq(_governor.registrar(), address(_registrar));
        assertEq(_governor.voteToken(), address(_powerToken));
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _governor.clock();

        _governor.setProposal(proposalId_, currentEpoch + 1, currentEpoch + 10);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchGovernor.ProposalNotActive.selector, IGovernor.ProposalState.Pending)
        );

        _governor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_votedOnFirstOfSeveralProposals() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _governor.clock();

        _governor.setProposal(proposalId_, currentEpoch, currentEpoch + 1);
        _governor.setNumberOfProposals(currentEpoch, 10);

        _powerToken.setVotePower(1);
        _powerToken.setTotalSupplyAt(1);

        // TODO: Expect _no_ IPowerToken.markParticipation
        // TODO: Expect _no_ IZeroToken.mint

        vm.prank(_alice);
        _governor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_governor.numberOfProposalsVotedOnAt(currentEpoch, _alice), 1);
    }

    function test_castVote_votedOnAllProposals() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _governor.clock();

        _governor.setProposal(proposalId_, currentEpoch, currentEpoch + 1);
        _governor.setNumberOfProposals(currentEpoch, 1);

        _powerToken.setVotePower(1);
        _powerToken.setTotalSupplyAt(1);

        // TODO: Expect IPowerToken.markParticipation
        // TODO: Expect IZeroToken.mint

        vm.prank(_alice);
        _governor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_governor.numberOfProposalsVotedOnAt(currentEpoch, _alice), 1);
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidTargetsLength() external {
        vm.expectRevert(IBatchGovernor.InvalidTargetsLength.selector);
        _governor.propose(new address[](2), new uint256[](0), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidTarget() external {
        vm.expectRevert(IBatchGovernor.InvalidTarget.selector);
        _governor.propose(new address[](1), new uint256[](0), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidValuesLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        vm.expectRevert(IBatchGovernor.InvalidValuesLength.selector);
        _governor.propose(targets_, new uint256[](2), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidValue() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 1;

        vm.expectRevert(IBatchGovernor.InvalidValue.selector);
        _governor.propose(targets_, values_, new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidCallDatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        vm.expectRevert(IBatchGovernor.InvalidCallDatasLength.selector);
        _governor.propose(targets_, new uint256[](1), new bytes[](2), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_proposalExists_withHarness() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_governor.setProposalFee.selector, 1);

        uint256 voteStart_ = _governor.clock() + _governor.votingDelay();

        _governor.setProposal(_governor.hashProposal(callDatas_[0]), voteStart_, voteStart_);

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _governor.propose(targets_, new uint256[](1), callDatas_, "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_proposalExists() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_governor.setProposalFee.selector, 1);

        _goToNextTransferEpoch();

        _governor.propose(targets_, new uint256[](1), callDatas_, "");

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _governor.propose(targets_, new uint256[](1), callDatas_, "");

        _goToNextEpoch();

        _governor.propose(targets_, new uint256[](1), callDatas_, "");

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _governor.propose(targets_, new uint256[](1), callDatas_, "");
    }

    // TODO: This can be duplicated into a `BatchGovernor.t.sol -> test_propose_invalidCallData`.
    function test_propose_invalidCallData() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _governor.propose(targets_, new uint256[](1), new bytes[](1), "");
    }

    // TODO: This can be duplicated into a `BatchGovernor.t.sol -> test_propose_invalidCallData`.
    function test_execute_proposalCannotBeExecuted() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_governor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_governor.setProposalFee.selector, 1);

        uint256 proposalId_ = _governor.hashProposal(callDatas_[0]);

        _governor.setProposal(proposalId_, 1, 1);

        vm.expectRevert(IBatchGovernor.ProposalCannotBeExecuted.selector);
        _governor.execute(targets_, new uint256[](1), callDatas_, keccak256(bytes("")));
    }

    function test_setCashToken_notZeroGovernor() external {
        vm.expectRevert(IStandardGovernor.NotZeroGovernor.selector);

        _governor.setCashToken(makeAddr("someCashToken"), _proposalFee);
    }

    function test_setCashToken() external {
        address _cashToken2 = makeAddr("someCashToken");

        vm.expectEmit();
        emit CashTokenSet(_cashToken2);

        vm.expectEmit();
        emit ProposalFeeSet(_proposalFee * 2);

        vm.prank(_zeroGovernor);
        _governor.setCashToken(_cashToken2, _proposalFee * 2);

        assertEq(_governor.cashToken(), _cashToken2);
        assertEq(_governor.proposalFee(), _proposalFee * 2);
    }

    // TODO: This can be duplicated into a `EmergencyGovernor.t.sol -> test_addAndRemoveFromList_notSelf`.
    function test_addAndRemoveFromList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);

        _governor.addAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    // TODO: This can be duplicated into a `EmergencyGovernor.t.sol -> test_addAndRemoveFromList`.
    function test_addAndRemoveFromList() external {
        vm.prank(address(_governor));
        _governor.addAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    function test_sendProposalFeeToVault_feeNotDestinedForVault() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch_ = _governor.clock();

        _governor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _governor.setProposal(proposalId_, currentEpoch_, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IStandardGovernor.FeeNotDestinedForVault.selector, 1));
        _governor.sendProposalFeeToVault(proposalId_);
    }

    function test_sendProposalFeeToVault() external {
        uint256 proposalId_ = 1;

        _governor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _governor.setProposal(proposalId_, 1, 1);

        vm.expectEmit();
        emit ProposalFeeSentToVault(proposalId_, address(_cashToken), 1000);

        _governor.sendProposalFeeToVault(proposalId_);
    }
}
