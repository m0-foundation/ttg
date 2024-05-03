// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";

import { BatchGovernorHarness } from "./utils/BatchGovernorHarness.sol";
import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract BatchGovernorTests is TestUtils {
    struct FiveProposalIds {
        uint256 proposalId1;
        uint256 proposalId2;
        uint256 proposalId3;
        uint256 proposalId4;
        uint256 proposalId5;
    }

    struct FiveSupports {
        uint8 support1;
        uint8 support2;
        uint8 support3;
        uint8 support4;
        uint8 support5;
    }

    struct TwoReasons {
        bytes32 reason1;
        bytes32 reason2;
    }

    address internal _alice;
    uint256 internal _aliceKey;

    BatchGovernorHarness internal _batchGovernor;

    MockEpochBasedVoteToken internal _voteToken;

    function setUp() external {
        (_alice, _aliceKey) = makeAddrAndKey("alice");

        _voteToken = new MockEpochBasedVoteToken();
        _batchGovernor = new BatchGovernorHarness("BatchGovernor", address(_voteToken));
    }

    /* ============ typeHashes ============ */
    function test_ballotTypeHash() external {
        assertEq(_batchGovernor.BALLOT_TYPEHASH(), keccak256("Ballot(uint256 proposalId,uint8 support)"));
    }

    function test_ballotWithReasonTypeHash() external {
        assertEq(
            _batchGovernor.BALLOT_WITH_REASON_TYPEHASH(),
            keccak256("BallotWithReason(uint256 proposalId,uint8 support,string reason)")
        );
    }

    function test_ballotsTypeHash() external {
        assertEq(_batchGovernor.BALLOTS_TYPEHASH(), keccak256("Ballots(uint256[] proposalIds,uint8[] supportList)"));
    }

    function test_ballotsWithReasonTypeHash() external {
        assertEq(
            _batchGovernor.BALLOTS_WITH_REASON_TYPEHASH(),
            keccak256("BallotsWithReason(uint256[] proposalIds,uint8[] supportList,string[] reasonList)")
        );
    }

    /* ============ ballotDigests ============ */
    function test_getBallotDigest() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(
            _batchGovernor.getBallotDigest(proposalId_, support_),
            _batchGovernor.getDigest(keccak256(abi.encode(_batchGovernor.BALLOT_TYPEHASH(), proposalId_, support_)))
        );
    }

    function test_getBallotsDigest() external {
        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = 1;
        proposalIds_[1] = 2;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(
            _batchGovernor.getBallotsDigest(proposalIds_, supportList_),
            _batchGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _batchGovernor.BALLOTS_TYPEHASH(),
                        keccak256(abi.encodePacked(proposalIds_)),
                        keccak256(abi.encodePacked(supportList_))
                    )
                )
            )
        );
    }

    function test_getBallotWithReasonDigest() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);
        string memory reason_ = "Yes";

        assertEq(
            _batchGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_),
            _batchGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _batchGovernor.BALLOT_WITH_REASON_TYPEHASH(),
                        proposalId_,
                        support_,
                        keccak256(bytes(reason_))
                    )
                )
            )
        );
    }

    function test_getBallotsWithReasonDigest() external {
        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = 1;
        proposalIds_[1] = 2;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        string[] memory reasonList_ = new string[](2);
        reasonList_[0] = "First proposal - Yes";
        reasonList_[1] = "Second proposal - Yes";

        assertEq(
            _batchGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_),
            _batchGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _batchGovernor.BALLOTS_WITH_REASON_TYPEHASH(),
                        keccak256(abi.encodePacked(proposalIds_)),
                        keccak256(abi.encodePacked(supportList_)),
                        _batchGovernor.getReasonListHash(reasonList_)
                    )
                )
            )
        );
    }

    /* ============ listHash ============ */
    function test_proposalIdsHash() external {
        // NOTE: as mentioned in EIP-712:
        // The array values are encoded as the `keccak256` hash of the concatenated `encodeData` of their contents
        // (i.e. the encoding of `SomeType[5]` is identical to that of a struct containing five members of type `SomeType`).
        uint256[] memory proposalIds_ = new uint256[](5);
        proposalIds_[0] = 1;
        proposalIds_[1] = 2;
        proposalIds_[2] = 3;
        proposalIds_[3] = 4;
        proposalIds_[4] = 5;

        assertEq(
            keccak256(
                abi.encode(
                    FiveProposalIds(proposalIds_[0], proposalIds_[1], proposalIds_[2], proposalIds_[3], proposalIds_[4])
                )
            ),
            keccak256(abi.encodePacked(proposalIds_))
        );
    }

    function test_supportListHash() external {
        uint8[] memory supportList_ = new uint8[](5);
        supportList_[0] = 1;
        supportList_[1] = 2;
        supportList_[2] = 3;
        supportList_[3] = 4;
        supportList_[4] = 5;

        assertEq(
            keccak256(
                abi.encode(
                    FiveSupports(supportList_[0], supportList_[1], supportList_[2], supportList_[3], supportList_[4])
                )
            ),
            keccak256(abi.encodePacked(supportList_))
        );
    }

    function test_getReasonListHash() external {
        string[] memory reasonList1_ = new string[](2);
        reasonList1_[0] = "12";
        reasonList1_[1] = "3";

        string[] memory reasonList2_ = new string[](2);
        reasonList2_[0] = "1";
        reasonList2_[1] = "23";

        // NOTE: as mentioned in EIP-712:
        // The dynamic values `bytes` and `string` are encoded as a `keccak256` hash of their contents.
        assertEq(
            keccak256(abi.encode(TwoReasons(keccak256(bytes(reasonList1_[0])), keccak256(bytes(reasonList1_[1]))))),
            _batchGovernor.getReasonListHash(reasonList1_)
        );

        assertNotEq(_batchGovernor.getReasonListHash(reasonList1_), _batchGovernor.getReasonListHash(reasonList2_));
    }

    /* ============ tryExecute ============ */
    function test_tryExecute_invalidValue() external {
        vm.expectRevert(IBatchGovernor.InvalidValue.selector);
        _batchGovernor.tryExecute{ value: 1 }(new bytes(0), 0, 0);
    }

    function test_tryExecute_invalidEarliestVoteStart() external {
        vm.expectRevert(IBatchGovernor.InvalidVoteStart.selector);
        _batchGovernor.tryExecute(new bytes(0), 1, 0);
    }

    function test_tryExecute_proposalCannotBeExecuted() external {
        vm.expectRevert(IBatchGovernor.ProposalCannotBeExecuted.selector);
        _batchGovernor.tryExecute(new bytes(0), 10, 1);
    }

    function test_tryExecute() external {
        uint16 currentEpoch_ = _currentEpoch();

        uint256 proposalId_ = _batchGovernor.setProposal({
            callData_: new bytes(0),
            voteStart_: currentEpoch_ - 5,
            executed_: false,
            proposer_: address(0),
            thresholdRatio_: 0,
            noWeight_: 0,
            yesWeight_: 0
        });

        _batchGovernor.setState(proposalId_, IGovernor.ProposalState.Succeeded);

        assertEq(_batchGovernor.tryExecute(new bytes(0), currentEpoch_, currentEpoch_ - 10), proposalId_);
    }

    /* ============ castVote ============ */
    function test_castVote_zeroWeight() external {
        uint256 proposalId_ = 1;
        _batchGovernor.setState(proposalId_, IGovernor.ProposalState.Active);

        _voteToken.setVotePower(0);

        vm.expectRevert(IBatchGovernor.ZeroVotingPower.selector);

        vm.prank(_alice);
        _batchGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertFalse(_batchGovernor.hasVoted(proposalId_, _alice));
    }
}
