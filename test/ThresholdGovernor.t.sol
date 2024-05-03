// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";

import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";
import { ThresholdGovernorHarness } from "./utils/ThresholdGovernorHarness.sol";

contract ThresholdGovernorTests is TestUtils {
    address internal _alice;
    uint256 internal _aliceKey;

    uint16 internal _thresholdRatio = 6_500;

    ThresholdGovernorHarness internal _thresholdGovernor;

    MockEpochBasedVoteToken internal _voteToken;

    function setUp() external {
        (_alice, _aliceKey) = makeAddrAndKey("alice");

        _voteToken = new MockEpochBasedVoteToken();
        _thresholdGovernor = new ThresholdGovernorHarness("ThresholdGovernor", address(_voteToken), _thresholdRatio);
    }

    /* ============ castVote ============ */
    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _voteToken.setVotePower(1);

        _thresholdGovernor.setProposal(proposalId_, currentEpoch - 2, _thresholdRatio);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchGovernor.ProposalInactive.selector, IGovernor.ProposalState.Expired)
        );

        vm.prank(_alice);
        _thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_proposalDoesNotExist() external {
        uint256 proposalId_ = 1;

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ProposalDoesNotExist.selector));

        vm.prank(_alice);
        _thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_zeroWeight() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _voteToken.setVotePower(0);

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);

        vm.expectRevert(IBatchGovernor.ZeroVotingPower.selector);

        vm.prank(_alice);
        _thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertFalse(_thresholdGovernor.hasVoted(proposalId_, _alice));
    }

    function test_castVote_alreadyVoted() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(1, currentEpoch - 1);

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);
        _thresholdGovernor.setHasVoted(proposalId_, _alice);

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.AlreadyVoted.selector));

        vm.prank(_alice);
        _thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_voteYes() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(1, currentEpoch - 1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), 1);
    }

    function test_castVote_voteNo() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(1, currentEpoch - 1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.No), 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.No)), 1);
    }

    /* ============ castVoteBySig ============ */
    function test_castVoteBySig() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        _thresholdGovernor.setProposal(proposalId_, _thresholdGovernor.clock(), _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(_thresholdGovernor.clock() - 1, 1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, support_, 1, "");

        vm.prank(_alice);
        assertEq(
            _thresholdGovernor.castVoteBySig(
                _alice,
                proposalId_,
                support_,
                _getSignature(_thresholdGovernor.getBallotDigest(proposalId_, support_), _aliceKey)
            ),
            1
        );
    }

    function test_castVoteBySig_vrs() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        _thresholdGovernor.setProposal(proposalId_, _thresholdGovernor.clock(), _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(_thresholdGovernor.clock() - 1, 1);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _thresholdGovernor.getBallotDigest(proposalId_, support_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, support_, 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVoteBySig(proposalId_, support_, v_, r_, s_), 1);
    }

    /* ============ castVoteWithReason ============ */
    function test_castVoteWithReason() external {
        uint256 proposalId_ = 1;
        string memory reason_ = "Yes";

        _thresholdGovernor.setProposal(proposalId_, _thresholdGovernor.clock(), _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(_thresholdGovernor.clock() - 1, 1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reason_);

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVoteWithReason(proposalId_, uint8(IBatchGovernor.VoteType.Yes), reason_), 1);
    }

    /* ============ castVoteWithReasonBySig ============ */
    function test_castVoteWithReasonBySig() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);
        string memory reason_ = "Yes";

        _thresholdGovernor.setProposal(proposalId_, _thresholdGovernor.clock(), _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(_thresholdGovernor.clock() - 1, 1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reason_);

        vm.prank(_alice);
        assertEq(
            _thresholdGovernor.castVoteWithReasonBySig(
                _alice,
                proposalId_,
                uint8(IBatchGovernor.VoteType.Yes),
                reason_,
                _getSignature(_thresholdGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_), _aliceKey)
            ),
            1
        );
    }

    function test_castVoteWithReasonBySig_vrs() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);
        string memory reason_ = "Yes";

        _thresholdGovernor.setProposal(proposalId_, _thresholdGovernor.clock(), _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(_thresholdGovernor.clock() - 1, 1);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _thresholdGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reason_);

        vm.prank(_alice);
        assertEq(
            _thresholdGovernor.castVoteWithReasonBySig(
                proposalId_,
                uint8(IBatchGovernor.VoteType.Yes),
                reason_,
                v_,
                r_,
                s_
            ),
            1
        );
    }

    /* ============ castVotes ============ */
    function test_castVotes() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supports_ = new uint8[](2);
        supports_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supports_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotes(proposalIds_, supports_), 1);
    }

    function test_castVotes_multipleTimes() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 thirdProposalId_ = 3;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch, _thresholdRatio);
        _thresholdGovernor.setProposal(thirdProposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch - 1, 1);

        uint256[] memory firstBatchOfProposalIds_ = new uint256[](2);
        firstBatchOfProposalIds_[0] = firstProposalId_;
        firstBatchOfProposalIds_[1] = secondProposalId_;

        uint8[] memory firstBatchOfSupports_ = new uint8[](2);
        firstBatchOfSupports_[0] = uint8(IBatchGovernor.VoteType.Yes);
        firstBatchOfSupports_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotes(firstBatchOfProposalIds_, firstBatchOfSupports_), 1);

        uint256[] memory secondBatchOfProposalIds_ = new uint256[](1);
        secondBatchOfProposalIds_[0] = thirdProposalId_;

        uint8[] memory secondBatchOfSupports_ = new uint8[](1);
        secondBatchOfSupports_[0] = uint8(IBatchGovernor.VoteType.No);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, thirdProposalId_, uint8(IBatchGovernor.VoteType.No), 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotes(secondBatchOfProposalIds_, secondBatchOfSupports_), 1);
    }

    function test_castVotes_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _thresholdGovernor.castVotes(new uint256[](1), new uint8[](2));
    }

    function test_castVotes_emptyProposalIdsArray() external {
        vm.expectRevert(IBatchGovernor.EmptyProposalIdsArray.selector);

        vm.prank(_alice);
        _thresholdGovernor.castVotes(new uint256[](0), new uint8[](0));
    }

    /* ============ castVotesBySig ============ */
    function test_castVotesBySig() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch_, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch_, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch_ - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.prank(_alice);
        assertEq(
            _thresholdGovernor.castVotesBySig(
                _alice,
                proposalIds_,
                supportList_,
                _getSignature(_thresholdGovernor.getBallotsDigest(proposalIds_, supportList_), _aliceKey)
            ),
            1
        );
    }

    function test_castVotesBySig_vrs() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch_, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch_, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch_ - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _thresholdGovernor.getBallotsDigest(proposalIds_, supportList_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, "");

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotesBySig(proposalIds_, supportList_, v_, r_, s_), 1);
    }

    /* ============ castVotesWithReason ============ */
    function test_castVotesWithReason() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch_, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch_, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch_ - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        string[] memory reasonList_ = new string[](2);
        reasonList_[0] = "First proposal - Yes";
        reasonList_[1] = "Second proposal - Yes";

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[0]);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[1]);

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotesWithReason(proposalIds_, supportList_, reasonList_), 1);
    }

    function test_castVotesWithReason_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _thresholdGovernor.castVotesWithReason(new uint256[](1), new uint8[](2), new string[](2));

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _thresholdGovernor.castVotesWithReason(new uint256[](1), new uint8[](1), new string[](2));
    }

    function test_castVotesWithReason_emptyProposalIdsArray() external {
        vm.expectRevert(IBatchGovernor.EmptyProposalIdsArray.selector);

        vm.prank(_alice);
        _thresholdGovernor.castVotesWithReason(new uint256[](0), new uint8[](0), new string[](0));
    }

    /* ============ castVotesWithReasonBySig ============ */
    function test_castVotesWithReasonBySig() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch_, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch_, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch_ - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        string[] memory reasonList_ = new string[](2);
        reasonList_[0] = "First proposal - Yes";
        reasonList_[1] = "Second proposal - Yes";

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[0]);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[1]);

        vm.prank(_alice);
        assertEq(
            _thresholdGovernor.castVotesWithReasonBySig(
                _alice,
                proposalIds_,
                supportList_,
                reasonList_,
                _getSignature(
                    _thresholdGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_),
                    _aliceKey
                )
            ),
            1
        );
    }

    function test_castVotesWithReasonBySig_vrs() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(firstProposalId_, currentEpoch_, _thresholdRatio);
        _thresholdGovernor.setProposal(secondProposalId_, currentEpoch_, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch_ - 1, 1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        string[] memory reasonList_ = new string[](2);
        reasonList_[0] = "First proposal - Yes";
        reasonList_[1] = "Second proposal - Yes";

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _thresholdGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[0]);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), 1, reasonList_[1]);

        vm.prank(_alice);
        assertEq(_thresholdGovernor.castVotesWithReasonBySig(proposalIds_, supportList_, reasonList_, v_, r_, s_), 1);
    }

    /* ============ state ============ */
    function test_state_activeThenDefeatedNobodyVoted() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setPastTotalSupply(currentEpoch - 1, 1);

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_state_activeThenDefeatedInsufficientYesVotes() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, _thresholdRatio);

        _voteToken.setVotePower(1);
        _voteToken.setPastTotalSupply(currentEpoch - 1, 2);

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        vm.prank(_alice);
        _thresholdGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_state_succeededThenExpired() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, false, _alice, _thresholdRatio, 0, 1);

        _voteToken.setPastTotalSupply(currentEpoch - 1, 1);

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));

        _warpToNextEpoch();

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Expired));
    }

    function test_state_executed() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _thresholdGovernor.clock();

        _thresholdGovernor.setProposal(proposalId_, currentEpoch, true, _alice, _thresholdRatio, 0, 1);

        assertEq(uint256(_thresholdGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Executed));
    }

    /* ============ execute ============ */
    function test_execute_invalidTargetsLength() external {
        vm.expectRevert(IBatchGovernor.InvalidTargetsLength.selector);
        _thresholdGovernor.execute(new address[](2), new uint256[](0), new bytes[](0), "");
    }

    function test_execute_invalidTarget() external {
        vm.expectRevert(IBatchGovernor.InvalidTarget.selector);
        _thresholdGovernor.execute(new address[](1), new uint256[](0), new bytes[](0), "");
    }

    function test_execute_invalidValuesLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_thresholdGovernor);

        vm.expectRevert(IBatchGovernor.InvalidValuesLength.selector);
        _thresholdGovernor.execute(targets_, new uint256[](2), new bytes[](0), "");
    }

    function test_execute_invalidValue() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_thresholdGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 1;

        vm.expectRevert(IBatchGovernor.InvalidValue.selector);
        _thresholdGovernor.execute(targets_, values_, new bytes[](0), "");
    }

    function test_execute_invalidCallDatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_thresholdGovernor);

        vm.expectRevert(IBatchGovernor.InvalidCallDatasLength.selector);
        _thresholdGovernor.execute(targets_, new uint256[](1), new bytes[](2), "");
    }

    /* ============ View Functions ============ */

    /* ============ getProposal ============ */

    /* ============ getProposal ============ */
    function test_getProposal_proposalDoesNotExist() external {
        vm.expectRevert(IBatchGovernor.ProposalDoesNotExist.selector);
        _thresholdGovernor.getProposal(0);
    }

    function test_getProposal() external {
        _voteToken.setPastTotalSupply(_currentEpoch() - 1, 1_000_000);

        _thresholdGovernor.setProposal({
            proposalId_: 1,
            voteStart_: _currentEpoch(),
            executed_: false,
            proposer_: address(1),
            thresholdRatio_: 4_000,
            noWeight_: 111,
            yesWeight_: 222
        });

        (
            uint48 voteStart_,
            uint48 voteEnd_,
            IGovernor.ProposalState state_,
            uint256 noVotes_,
            uint256 yesVotes_,
            address proposer_,
            uint256 quorum_,
            uint16 quorumNumerator_
        ) = _thresholdGovernor.getProposal(1);

        assertEq(voteStart_, _currentEpoch());
        assertEq(voteEnd_, _currentEpoch() + 1);
        assertEq(uint8(state_), uint8(IGovernor.ProposalState.Active));
        assertEq(noVotes_, 111);
        assertEq(yesVotes_, 222);
        assertEq(proposer_, address(1));
        assertEq(quorum_, 400_000);
        assertEq(quorumNumerator_, 4_000);
    }

    function test_quorum() external {
        _voteToken.setPastTotalSupply(_currentEpoch() - 1, 1_000_000);

        assertEq(_thresholdGovernor.quorum(), 650_000);
    }

    function test_quorumNumerator() external {
        assertEq(_thresholdGovernor.quorumNumerator(), _thresholdRatio);
    }

    function test_quorumDenominator() external {
        assertEq(_thresholdGovernor.quorumDenominator(), 10_000);
    }

    function test_votingDelay() external {
        assertEq(_thresholdGovernor.votingDelay(), 0);
    }

    function test_votingPeriod() external {
        assertEq(_thresholdGovernor.votingPeriod(), 1);
    }
}
