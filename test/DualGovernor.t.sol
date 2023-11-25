// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";

import { DualGovernorHarness } from "./utils/DualGovernorHarness.sol";
import { MockPowerToken, MockRegistrar, MockZeroToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_ProposalShouldChangeStatesCorrectly
// TODO: test_CanVoteOnMultipleProposals
// TODO: test_UserVoteInflationAfterVotingOnAllProposals
// TODO: test_DelegateValueRewardsAfterVotingOnAllProposals
// TODO: test_state matrix.

contract DualGovernorTests is TestUtils {
    event CashTokenSet(address indexed cashToken_);
    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 proposalFee);
    event ProposalFeeSet(uint256 proposalFee_);

    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");
    address internal _vault = makeAddr("vault");

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    uint256 internal _powerTokenThresholdRatio = _ONE / 40;
    uint256 internal _zeroTokenThresholdRatio = _ONE / 60;
    uint256 internal _maxTotalZeroRewardPerActiveEpoch = 1_000;
    uint256 internal _proposalFee = 5;

    DualGovernorHarness internal _dualGovernor;
    MockPowerToken internal _powerToken;
    MockZeroToken internal _zeroToken;
    MockRegistrar internal _registrar;

    function setUp() external {
        _powerToken = new MockPowerToken();
        _zeroToken = new MockZeroToken();
        _registrar = new MockRegistrar();

        _dualGovernor = new DualGovernorHarness(
            address(_registrar),
            address(_powerToken),
            address(_zeroToken),
            _vault,
            _allowedCashTokens,
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch,
            uint16(_powerTokenThresholdRatio),
            uint16(_zeroTokenThresholdRatio)
        );
    }

    function test_initialState() external {
        assertEq(_dualGovernor.powerToken(), address(_powerToken));
        assertEq(_dualGovernor.registrar(), address(_registrar));
        assertEq(_dualGovernor.vault(), _vault);
        assertEq(_dualGovernor.zeroToken(), address(_zeroToken));
        assertEq(_dualGovernor.maxTotalZeroRewardPerActiveEpoch(), _maxTotalZeroRewardPerActiveEpoch);
        assertEq(_dualGovernor.cashToken(), _allowedCashTokens[0]);
        assertEq(_dualGovernor.proposalFee(), _proposalFee);
        assertEq(_dualGovernor.powerTokenThresholdRatio(), _powerTokenThresholdRatio);
        assertEq(_dualGovernor.zeroTokenThresholdRatio(), _zeroTokenThresholdRatio);

        assertTrue(_dualGovernor.isAllowedCashToken(_cashToken1));
        assertTrue(_dualGovernor.isAllowedCashToken(_cashToken2));
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
            _powerTokenThresholdRatio
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

    function test_propose_invalidCallDatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        vm.expectRevert(IDualGovernor.InvalidCallDatasLength.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](2), "");
    }

    function test_propose_proposalExists_withHarness() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_dualGovernor.resetToZeroHolders.selector);

        _dualGovernor.setProposal(_dualGovernor.hashProposal(callDatas_[0]), IDualGovernor.ProposalType.Zero, 1, 1, 0);

        vm.expectRevert(IDualGovernor.ProposalExists.selector);
        _dualGovernor.propose(targets_, values_, callDatas_, "");
    }

    function test_propose_proposalExists() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_dualGovernor.resetToZeroHolders.selector);

        _goToNextTransferEpoch();

        _dualGovernor.propose(targets_, values_, callDatas_, "");

        vm.expectRevert(IDualGovernor.ProposalExists.selector);
        _dualGovernor.propose(targets_, values_, callDatas_, "");

        _goToNextEpoch();

        _dualGovernor.propose(targets_, values_, callDatas_, "");

        vm.expectRevert(IDualGovernor.ProposalExists.selector);
        _dualGovernor.propose(targets_, values_, callDatas_, "");
    }

    function test_propose_invalidProposalType() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 0;

        vm.expectRevert(IDualGovernor.InvalidProposalType.selector);
        _dualGovernor.propose(targets_, values_, new bytes[](1), "");
    }

    function test_execute_proposalCannotBeExecuted() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_dualGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_dualGovernor.setProposalFee.selector, 1);

        uint256 proposalId_ = _dualGovernor.hashProposal(callDatas_[0]);

        _dualGovernor.setProposal(proposalId_, IDualGovernor.ProposalType.Standard, 1, 1, _powerTokenThresholdRatio);

        vm.expectRevert(IDualGovernor.ProposalCannotBeExecuted.selector);
        _dualGovernor.execute(targets_, values_, callDatas_, keccak256(bytes("")));
    }

    function test_setCashToken_notSelf() external {
        vm.expectRevert(IDualGovernor.NotSelf.selector);

        _dualGovernor.setCashToken(makeAddr("someCashToken"), _proposalFee);
    }

    function test_setCashToken_invalidCashToken() external {
        vm.expectRevert(IDualGovernor.InvalidCashToken.selector);

        vm.prank(address(_dualGovernor));
        _dualGovernor.setCashToken(makeAddr("someCashToken"), _proposalFee);
    }

    function test_setCashToken() external {
        vm.expectEmit();
        emit CashTokenSet(_cashToken2);

        vm.expectEmit();
        emit ProposalFeeSet(_proposalFee * 2);

        vm.prank(address(_dualGovernor));
        _dualGovernor.setCashToken(_cashToken2, _proposalFee * 2);

        assertEq(_dualGovernor.cashToken(), _cashToken2);
        assertEq(_dualGovernor.proposalFee(), _proposalFee * 2);
    }

    function test_addAndRemoveFromList_notSelf() external {
        vm.expectRevert(IDualGovernor.NotSelf.selector);

        _dualGovernor.addAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    function test_addAndRemoveFromList() external {
        vm.prank(address(_dualGovernor));
        _dualGovernor.addAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    function test_emergencyAddAndRemoveFromList_notSelf() external {
        vm.expectRevert(IDualGovernor.NotSelf.selector);

        _dualGovernor.emergencyAddAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    function test_emergencyAddAndRemoveFromList() external {
        vm.prank(address(_dualGovernor));
        _dualGovernor.emergencyAddAndRemoveFromList("SOME_LIST", _alice, _bob);
    }

    function test_sendProposalFeeToVault_feeNotDestinedForVault() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch_ = _dualGovernor.clock();

        _dualGovernor.setProposalFeeInfo(proposalId_, _cashToken1, 1000);
        _dualGovernor.setProposal(proposalId_, IDualGovernor.ProposalType.Standard, currentEpoch_, currentEpoch_, 1);

        vm.expectRevert(abi.encodeWithSelector(IDualGovernor.FeeNotDestinedForVault.selector, 1));
        _dualGovernor.sendProposalFeeToVault(proposalId_);
    }

    function test_sendProposalFeeToVault() external {
        uint256 proposalId_ = 1;

        _dualGovernor.setProposalFeeInfo(proposalId_, _cashToken1, 1000);
        _dualGovernor.setProposal(proposalId_, IDualGovernor.ProposalType.Standard, 1, 1, 1);

        vm.expectEmit();
        emit ProposalFeeSentToVault(proposalId_, _cashToken1, 1000);

        _dualGovernor.sendProposalFeeToVault(proposalId_);
    }
}
