// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";
import { IPowerTokenDeployer } from "../src/interfaces/IPowerTokenDeployer.sol";

import { StandardGovernorHarness } from "./utils/StandardGovernorHarness.sol";
import {
    MockERC20,
    MockPowerToken,
    MockPowerTokenDeployer,
    MockRegistrar,
    MockZeroGovernor,
    MockZeroToken
} from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_CanVoteOnMultipleProposals
// TODO: test_state matrix.

contract StandardGovernorTests is TestUtils {
    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _vault = makeAddr("vault");

    uint256 internal _maxTotalZeroRewardPerActiveEpoch = 1_000;
    uint256 internal _proposalFee = 5;
    uint256 internal _votePower = 1;

    StandardGovernorHarness internal _standardGovernor;

    MockERC20 internal _cashToken;
    MockPowerToken internal _powerToken;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockRegistrar internal _registrar;
    MockZeroGovernor internal _zeroGovernor;
    MockZeroToken internal _zeroToken;

    function setUp() external {
        _cashToken = new MockERC20();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _powerToken = new MockPowerToken();
        _zeroGovernor = new MockZeroGovernor();
        _zeroToken = new MockZeroToken();
        _registrar = new MockRegistrar();

        _zeroGovernor.setPowerTokenDeployer(address(_powerTokenDeployer));
        _powerTokenDeployer.setLastDeploy(address(_powerToken));

        _standardGovernor = new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            address(_zeroGovernor),
            address(_cashToken),
            address(_registrar),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

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

    /* ============ constructor ============ */
    function test_constructor_invalidVoteTokenAddress() external {
        vm.expectRevert(IBatchGovernor.InvalidVoteTokenAddress.selector);
        new StandardGovernorHarness(
            address(0),
            _emergencyGovernor,
            address(_zeroGovernor),
            address(_cashToken),
            address(_registrar),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    function test_constructor_invalidEmergencyGovernorDeployerAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidEmergencyGovernorAddress.selector);
        new StandardGovernorHarness(
            address(_powerToken),
            address(0),
            address(_zeroGovernor),
            address(_cashToken),
            address(_registrar),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    function test_constructor_invalidZeroGovernorAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidZeroGovernorAddress.selector);
        new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            address(0),
            address(_cashToken),
            address(_registrar),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    function test_constructor_invalidRegistrarAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidRegistrarAddress.selector);
        new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            address(_zeroGovernor),
            address(_cashToken),
            address(0),
            _vault,
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    function test_constructor_invalidVaultAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidVaultAddress.selector);
        new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            address(_zeroGovernor),
            address(_cashToken),
            address(_registrar),
            address(0),
            address(_zeroToken),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    function test_constructor_invalidZeroTokenAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidZeroTokenAddress.selector);
        new StandardGovernorHarness(
            address(_powerToken),
            _emergencyGovernor,
            address(_zeroGovernor),
            address(_cashToken),
            address(_registrar),
            _vault,
            address(0),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    /* ============ castVote ============ */
    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch + 1);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchGovernor.ProposalNotActive.selector, IGovernor.ProposalState.Pending)
        );

        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_alreadyVoted() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);
        _standardGovernor.setHasVoted(proposalId_, _alice);

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.AlreadyVoted.selector));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_voteYes() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);
    }

    function test_castVote_voteNo() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.No), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.No)), _votePower);
    }

    function test_castVote_votedOnFirstOfSeveralProposals() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, 10);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    function test_castVote_votedOnAllProposals() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, 1);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    /* ============ castVotes ============ */
    function test_castVotes() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supports_ = new uint8[](2);
        supports_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supports_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotes(proposalIds_, supports_), _votePower);
    }

    /* ============ propose ============ */
    function test_propose_invalidTargetsLength() external {
        vm.expectRevert(IBatchGovernor.InvalidTargetsLength.selector);
        _standardGovernor.propose(new address[](2), new uint256[](0), new bytes[](0), "");
    }

    function test_propose_invalidTarget() external {
        vm.expectRevert(IBatchGovernor.InvalidTarget.selector);
        _standardGovernor.propose(new address[](1), new uint256[](0), new bytes[](0), "");
    }

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

        _standardGovernor.setProposal(_standardGovernor.hashProposal(callDatas_[0]), voteStart_);

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");
    }

    // TODO: This is really a test for `BatchGovernor.t.sol`.
    function test_propose_proposalExists() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        _warpToNextTransferEpoch();

        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "");

        _warpToNextVoteEpoch();

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

    /* ============ execute ============ */
    // TODO: This can be duplicated into a `BatchGovernor.t.sol -> test_propose_invalidCallData`.
    function test_execute_proposalCannotBeExecuted() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        uint256 proposalId_ = _standardGovernor.hashProposal(callDatas_[0]);

        _standardGovernor.setProposal(proposalId_, 1);

        vm.expectRevert(IBatchGovernor.ProposalCannotBeExecuted.selector);
        _standardGovernor.execute(targets_, new uint256[](1), callDatas_, keccak256(bytes("")));
    }

    /* ============ setCashToken ============ */
    function test_setCashToken_notZeroGovernor() external {
        vm.expectRevert(IStandardGovernor.NotZeroGovernor.selector);
        _standardGovernor.setCashToken(makeAddr("someCashToken"), _proposalFee);
    }

    function test_setCashToken_invalidCashTokenAddress() external {
        vm.expectRevert(IStandardGovernor.InvalidCashTokenAddress.selector);

        vm.prank(address(_zeroGovernor));
        _standardGovernor.setCashToken(address(0), _proposalFee);
    }

    function test_setCashToken() external {
        address _cashToken2 = makeAddr("someCashToken");

        vm.expectEmit();
        emit IStandardGovernor.CashTokenSet(_cashToken2);

        vm.expectEmit();
        emit IStandardGovernor.ProposalFeeSet(_proposalFee * 2);

        vm.prank(address(_zeroGovernor));
        _standardGovernor.setCashToken(_cashToken2, _proposalFee * 2);

        assertEq(_powerToken.cashToken(), _cashToken2);
        assertEq(_standardGovernor.cashToken(), _cashToken2);
        assertEq(_standardGovernor.proposalFee(), _proposalFee * 2);
    }

    /* ============ sendProposalFeeToVault ============ */
    function test_sendProposalFeeToVault_feeNotDestinedForVault() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _standardGovernor.setProposal(proposalId_, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IStandardGovernor.FeeNotDestinedForVault.selector, 1));
        _standardGovernor.sendProposalFeeToVault(proposalId_);
    }

    function test_sendProposalFeeToVault() external {
        uint256 proposalId_ = 1;

        _standardGovernor.setProposalFeeInfo(proposalId_, address(_cashToken), 1000);
        _standardGovernor.setProposal(proposalId_, 1);

        vm.expectEmit();
        emit IStandardGovernor.ProposalFeeSentToVault(proposalId_, address(_cashToken), 1000);

        _standardGovernor.sendProposalFeeToVault(proposalId_);
    }

    /* ============ View Functions ============ */

    function test_quorum() external {
        assertEq(_standardGovernor.quorum(), 0);
        assertEq(_standardGovernor.quorum(1), 0);
    }

    function test_votingDelay() external {
        _warpToNextVoteEpoch();
        assertEq(_standardGovernor.votingDelay(), 2);

        _warpToNextTransferEpoch();
        assertEq(_standardGovernor.votingDelay(), 1);
    }

    function test_votingPeriod() external {
        assertEq(_standardGovernor.votingPeriod(), 0);
    }

    /* ============ Proposal Functions ============ */

    /* ============ addToList ============ */
    function test_addToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _standardGovernor.addToList("SOME_LIST", _alice);
    }

    /* ============ removeFromList ============ */
    function test_removeFromList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _standardGovernor.removeFromList("SOME_LIST", _alice);
    }

    /* ============ removeFromAndAddToList ============ */
    function test_removeFromAndAddToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _standardGovernor.removeFromAndAddToList("SOME_LIST", _alice, _bob);
    }

    /* ============ setKey ============ */
    function test_setKey_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _standardGovernor.setKey(bytes32(0), bytes32(0));
    }

    /* ============ setProposalFee ============ */
    function test_setProposalFee_notSelf() external {
        vm.expectRevert(IStandardGovernor.NotSelfOrEmergencyGovernor.selector);
        _standardGovernor.setProposalFee(2e18);
    }

    function test_setProposalFee_bySelf() external {
        uint256 newProposalFee_ = 2e18;

        vm.expectEmit();
        emit IStandardGovernor.ProposalFeeSet(newProposalFee_);

        vm.prank(address(_standardGovernor));
        _standardGovernor.setProposalFee(newProposalFee_);
    }

    function test_setProposalFee_byEmergencyGovernor() external {
        uint256 newProposalFee_ = 2e18;

        vm.expectEmit();
        emit IStandardGovernor.ProposalFeeSet(newProposalFee_);

        vm.prank(address(_emergencyGovernor));
        _standardGovernor.setProposalFee(newProposalFee_);
    }

    /* ============ revertIfInvalidCalldata ============ */
    function test_revertIfInvalidCalldata() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(abi.encode("randomCalldata"));
    }
}
