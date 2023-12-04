// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

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
    event CashTokenSet(address indexed cashToken);
    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 amount);
    event ProposalFeeSet(uint256 proposalFee);

    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _vault = makeAddr("vault");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    uint256 internal _maxTotalZeroRewardPerActiveEpoch = 1_000;
    uint256 internal _proposalFee = 5;

    StandardGovernorHarness internal _standardGovernor;

    MockERC20 internal _cashToken;
    MockPowerToken internal _powerToken;
    MockRegistrar internal _registrar;
    MockZeroToken internal _zeroToken;

    function setUp() external {
        _cashToken = new MockERC20();
        _powerToken = new MockPowerToken();
        _zeroToken = new MockZeroToken();
        _registrar = new MockRegistrar();

        _standardGovernor = new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            _zeroGovernor,
            address(_cashToken),
            address(_registrar),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    // TODO: A portion of this can be duplicated into a `BatchGovernor.t.sol -> test_initialState`.
    function test_initialState() external {
        assertEq(_standardGovernor.emergencyGovernor(), address(_emergencyGovernor));
        assertEq(_standardGovernor.vault(), _vault);
        assertEq(_standardGovernor.zeroGovernor(), address(_zeroGovernor));
        assertEq(_standardGovernor.zeroToken(), address(_zeroToken));
        assertEq(_standardGovernor.maxTotalZeroRewardPerActiveEpoch(), _maxTotalZeroRewardPerActiveEpoch);
        assertEq(_standardGovernor.cashToken(), address(_cashToken));
        assertEq(_standardGovernor.proposalFee(), _proposalFee);
        assertEq(_standardGovernor.registrar(), address(_registrar));
        assertEq(_standardGovernor.voteToken(), address(_powerToken));
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch + 1, currentEpoch + 10);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchGovernor.ProposalNotActive.selector, IGovernor.ProposalState.Pending)
        );

        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_votedOnFirstOfSeveralProposals() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch, currentEpoch + 1);
        _standardGovernor.setNumberOfProposals(currentEpoch, 10);

        _powerToken.setVotePower(1);
        _powerToken.setPastTotalSupply(1);

        // TODO: Expect _no_ IPowerToken.markParticipation
        // TODO: Expect _no_ IZeroToken.mint

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    function test_castVote_votedOnAllProposals() external {
        uint256 proposalId_ = 1;

        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch, currentEpoch + 1);
        _standardGovernor.setNumberOfProposals(currentEpoch, 1);

        _powerToken.setVotePower(1);
        _powerToken.setPastTotalSupply(1);

        // TODO: Expect IPowerToken.markParticipation
        // TODO: Expect IZeroToken.mint

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidTargetsLength() external {
        vm.expectRevert(IBatchGovernor.InvalidTargetsLength.selector);
        _standardGovernor.propose(new address[](2), new uint256[](0), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidTarget() external {
        vm.expectRevert(IBatchGovernor.InvalidTarget.selector);
        _standardGovernor.propose(new address[](1), new uint256[](0), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidValuesLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        vm.expectRevert(IBatchGovernor.InvalidValuesLength.selector);
        _standardGovernor.propose(targets_, new uint256[](2), new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidValue() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 1;

        vm.expectRevert(IBatchGovernor.InvalidValue.selector);
        _standardGovernor.propose(targets_, values_, new bytes[](0), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_invalidCallDatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        vm.expectRevert(IBatchGovernor.InvalidCallDatasLength.selector);
        _standardGovernor.propose(targets_, new uint256[](1), new bytes[](2), "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_proposalExists_withHarness() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        uint256 voteStart_ = _standardGovernor.clock() + _standardGovernor.votingDelay();

        _standardGovernor.setProposal(_standardGovernor.hashProposal(callDatas_[0]), voteStart_, voteStart_);

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_proposalExists() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        _goToNextTransferEpoch();

        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        _goToNextEpoch();

        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");
    }

    // TODO: This can be duplicated into a `BatchGovernor.t.sol -> test_propose_invalidCallData`.
    function test_propose_invalidCallData() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.propose(targets_, new uint256[](1), new bytes[](1), "");
    }

    // TODO: This can be duplicated into a `BatchGovernor.t.sol -> test_propose_invalidCallData`.
    function test_execute_proposalCannotBeExecuted() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        uint256 proposalId_ = _standardGovernor.hashProposal(callDatas_[0]);

        _standardGovernor.setProposal(proposalId_, 1, 1);

        vm.expectRevert(IBatchGovernor.ProposalCannotBeExecuted.selector);
        _standardGovernor.execute(targets_, new uint256[](1), callDatas_, keccak256(bytes("")));
    }

    function test_setCashToken_notZeroGovernor() external {
        vm.expectRevert(IStandardGovernor.NotZeroGovernor.selector);

        _standardGovernor.setCashToken(makeAddr("someCashToken"), _proposalFee);
    }

    function test_setCashToken() external {
        address _cashToken2 = makeAddr("someCashToken");

        vm.expectEmit();
        emit CashTokenSet(_cashToken2);

        vm.expectEmit();
        emit ProposalFeeSet(_proposalFee * 2);

        vm.prank(_zeroGovernor);
        _standardGovernor.setCashToken(_cashToken2, _proposalFee * 2);

        assertEq(_standardGovernor.cashToken(), _cashToken2);
        assertEq(_standardGovernor.proposalFee(), _proposalFee * 2);
    }

    // TODO: This can be duplicated into a `EmergencyGovernor.t.sol -> test_removeFromAndAddToList_notSelf`.
    function test_removeFromAndAddToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);

        _standardGovernor.removeFromAndAddToList("SOME_LIST", _alice, _bob);
    }

    // TODO: This can be duplicated into a `EmergencyGovernor.t.sol -> test_removeFromAndAddToList`.
    function test_removeFromAndAddToList() external {
        vm.prank(address(_standardGovernor));
        _standardGovernor.removeFromAndAddToList("SOME_LIST", _alice, _bob);
    }

    function test_sendProposalFeeToVault_feeNotDestinedForVault() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _standardGovernor.setProposal(proposalId_, currentEpoch_, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IStandardGovernor.FeeNotDestinedForVault.selector, 1));
        _standardGovernor.sendProposalFeeToVault(proposalId_);
    }

    function test_sendProposalFeeToVault() external {
        uint256 proposalId_ = 1;

        _standardGovernor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _standardGovernor.setProposal(proposalId_, 1, 1);

        vm.expectEmit();
        emit ProposalFeeSentToVault(proposalId_, address(_cashToken), 1000);

        _standardGovernor.sendProposalFeeToVault(proposalId_);
    }
}
