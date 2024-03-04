// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";

import { StandardGovernorHarness } from "./utils/StandardGovernorHarness.sol";
import { MockERC20, MockPowerToken, MockRegistrar, MockZeroToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract StandardGovernorTests is TestUtils {
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

    uint256 internal constant _ONE = 10_000;

    address internal _alice;
    uint256 internal _aliceKey;

    address internal _bob = makeAddr("bob");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _vault = makeAddr("vault");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    uint256 internal _maxTotalZeroRewardPerActiveEpoch = 1_000;
    uint256 internal _proposalFee = 5;
    uint256 internal _votePower = 1;

    StandardGovernorHarness internal _standardGovernor;

    MockERC20 internal _cashToken;
    MockPowerToken internal _powerToken;
    MockRegistrar internal _registrar;
    MockZeroToken internal _zeroToken;

    address internal _account1 = makeAddr("account1");

    function setUp() external {
        (_alice, _aliceKey) = makeAddrAndKey("alice");

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

    function test_initialState() external {
        assertEq(_standardGovernor.emergencyGovernor(), address(_emergencyGovernor));
        assertEq(_standardGovernor.vault(), _vault);
        assertEq(_standardGovernor.zeroGovernor(), _zeroGovernor);
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
            _zeroGovernor,
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
            _zeroGovernor,
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
            _zeroGovernor,
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
            _zeroGovernor,
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
            _zeroGovernor,
            address(_cashToken),
            address(_registrar),
            _vault,
            address(0),
            _proposalFee,
            _maxTotalZeroRewardPerActiveEpoch
        );
    }

    /* ============ typeHashes ============ */
    function test_ballotTypeHash() external {
        assertEq(_standardGovernor.BALLOT_TYPEHASH(), keccak256("Ballot(uint256 proposalId,uint8 support)"));
    }

    function test_ballotWithReasonTypeHash() external {
        assertEq(
            _standardGovernor.BALLOT_WITH_REASON_TYPEHASH(),
            keccak256("BallotWithReason(uint256 proposalId,uint8 support,string reason)")
        );
    }

    function test_ballotsTypeHash() external {
        assertEq(_standardGovernor.BALLOTS_TYPEHASH(), keccak256("Ballots(uint256[] proposalIds,uint8[] supportList)"));
    }

    function test_ballotsWithReasonTypeHash() external {
        assertEq(
            _standardGovernor.BALLOTS_WITH_REASON_TYPEHASH(),
            keccak256("BallotsWithReason(uint256[] proposalIds,uint8[] supportList,string[] reasonList)")
        );
    }

    /* ============ ballotDigests ============ */
    function test_getBallotDigest() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(
            _standardGovernor.getBallotDigest(proposalId_, support_),
            _standardGovernor.getDigest(
                keccak256(abi.encode(_standardGovernor.BALLOT_TYPEHASH(), proposalId_, support_))
            )
        );
    }

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

    function test_getBallotsDigest() external {
        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = 1;
        proposalIds_[1] = 2;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(
            _standardGovernor.getBallotsDigest(proposalIds_, supportList_),
            _standardGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _standardGovernor.BALLOTS_TYPEHASH(),
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
            _standardGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_),
            _standardGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _standardGovernor.BALLOT_WITH_REASON_TYPEHASH(),
                        proposalId_,
                        support_,
                        keccak256(bytes(reason_))
                    )
                )
            )
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
            _standardGovernor.getReasonListHash(reasonList1_)
        );

        assertNotEq(
            _standardGovernor.getReasonListHash(reasonList1_),
            _standardGovernor.getReasonListHash(reasonList2_)
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
            _standardGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_),
            _standardGovernor.getDigest(
                keccak256(
                    abi.encode(
                        _standardGovernor.BALLOTS_WITH_REASON_TYPEHASH(),
                        keccak256(abi.encodePacked(proposalIds_)),
                        keccak256(abi.encodePacked(supportList_)),
                        _standardGovernor.getReasonListHash(reasonList_)
                    )
                )
            )
        );
    }

    /* ============ castVote ============ */
    function test_castVote_notActive() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch + 1);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchGovernor.ProposalInactive.selector, IGovernor.ProposalState.Pending)
        );

        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));
    }

    function test_castVote_proposalDoesNotExist() external {
        uint256 proposalId_ = 1;

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ProposalDoesNotExist.selector));

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

    function test_castVote_votedOnAllProposalsOnlyOneProposalExists() external {
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

        assertEq(_standardGovernor.hasVotedOnAllProposals(_alice, currentEpoch), true);

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    function test_castVote_votedOnAllProposalsMultipleProposalExists() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 thirdProposalId_ = 3;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch);
        _standardGovernor.setProposal(thirdProposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, 3);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(firstProposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(secondProposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, thirdProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(thirdProposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        assertEq(_standardGovernor.hasVotedOnAllProposals(_alice, currentEpoch), true);

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 3);
    }

    /* ============ castVoteBySig ============ */
    function test_castVoteBySig() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        _standardGovernor.setProposal(proposalId_, _standardGovernor.clock());

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, support_, _votePower, "");

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVoteBySig(
                _alice,
                proposalId_,
                support_,
                _getSignature(_standardGovernor.getBallotDigest(proposalId_, support_), _aliceKey)
            ),
            _votePower
        );
    }

    function test_castVoteBySig_vrs() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);

        _standardGovernor.setProposal(proposalId_, _standardGovernor.clock());

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _standardGovernor.getBallotDigest(proposalId_, support_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, support_, _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVoteBySig(proposalId_, support_, v_, r_, s_), _votePower);
    }

    /* ============ castVoteWithReason ============ */
    function test_castVoteWithReason() external {
        uint256 proposalId_ = 1;
        string memory reason_ = "Yes";

        _standardGovernor.setProposal(proposalId_, _standardGovernor.clock());

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, reason_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVoteWithReason(proposalId_, uint8(IBatchGovernor.VoteType.Yes), reason_),
            _votePower
        );
    }

    /* ============ castVoteWithReasonBySig ============ */
    function test_castVoteWithReasonBySig() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);
        string memory reason_ = "Yes";

        _standardGovernor.setProposal(proposalId_, _standardGovernor.clock());

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, reason_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVoteWithReasonBySig(
                _alice,
                proposalId_,
                uint8(IBatchGovernor.VoteType.Yes),
                reason_,
                _getSignature(_standardGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_), _aliceKey)
            ),
            _votePower
        );
    }

    function test_castVoteWithReasonBySig_vrs() external {
        uint256 proposalId_ = 1;
        uint8 support_ = uint8(IBatchGovernor.VoteType.Yes);
        string memory reason_ = "Yes";

        _standardGovernor.setProposal(proposalId_, _standardGovernor.clock());

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _standardGovernor.getBallotWithReasonDigest(proposalId_, support_, reason_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, reason_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVoteWithReasonBySig(
                proposalId_,
                uint8(IBatchGovernor.VoteType.Yes),
                reason_,
                v_,
                r_,
                s_
            ),
            _votePower
        );
    }

    /* ============ castVotes ============ */
    function test_castVotes() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, 2);

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

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotes(proposalIds_, supports_), _votePower);
    }

    function test_castVotes_multipleTimes() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 thirdProposalId_ = 3;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch);
        _standardGovernor.setProposal(thirdProposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, 3);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        uint256[] memory firstBatchOfProposalIds_ = new uint256[](2);
        firstBatchOfProposalIds_[0] = firstProposalId_;
        firstBatchOfProposalIds_[1] = secondProposalId_;

        uint8[] memory firstBatchOfSupports_ = new uint8[](2);
        firstBatchOfSupports_[0] = uint8(IBatchGovernor.VoteType.Yes);
        firstBatchOfSupports_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotes(firstBatchOfProposalIds_, firstBatchOfSupports_), _votePower);

        uint256[] memory secondBatchOfProposalIds_ = new uint256[](1);
        secondBatchOfProposalIds_[0] = thirdProposalId_;

        uint8[] memory secondBatchOfSupports_ = new uint8[](1);
        secondBatchOfSupports_[0] = uint8(IBatchGovernor.VoteType.No);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, thirdProposalId_, uint8(IBatchGovernor.VoteType.No), _votePower, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotes(secondBatchOfProposalIds_, secondBatchOfSupports_), _votePower);
    }

    function test_castVotes_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _standardGovernor.castVotes(new uint256[](1), new uint8[](2));
    }

    function test_castVotes_emptyProposalIdsArray() external {
        vm.expectRevert(IBatchGovernor.EmptyProposalIdsArray.selector);

        vm.prank(_alice);
        _standardGovernor.castVotes(new uint256[](0), new uint8[](0));
    }

    /* ============ castVotesBySig ============ */
    function test_castVotesBySig() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch_);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch_);
        _standardGovernor.setNumberOfProposals(currentEpoch_, 2);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVotesBySig(
                _alice,
                proposalIds_,
                supportList_,
                _getSignature(_standardGovernor.getBallotsDigest(proposalIds_, supportList_), _aliceKey)
            ),
            _votePower
        );
    }

    function test_castVotesBySig_vrs() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch_);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch_);
        _standardGovernor.setNumberOfProposals(currentEpoch_, 2);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = firstProposalId_;
        proposalIds_[1] = secondProposalId_;

        uint8[] memory supportList_ = new uint8[](2);
        supportList_[0] = uint8(IBatchGovernor.VoteType.Yes);
        supportList_[1] = uint8(IBatchGovernor.VoteType.Yes);

        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(
            _aliceKey,
            _standardGovernor.getBallotsDigest(proposalIds_, supportList_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, firstProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, secondProposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch_);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotesBySig(proposalIds_, supportList_, v_, r_, s_), _votePower);
    }

    /* ============ castVotesWithReason ============ */
    function test_castVotesWithReason() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch_);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch_);
        _standardGovernor.setNumberOfProposals(currentEpoch_, 2);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

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
        emit IGovernor.VoteCast(
            _alice,
            firstProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[0]
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(
            _alice,
            secondProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[1]
        );

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch_);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotesWithReason(proposalIds_, supportList_, reasonList_), _votePower);
    }

    function test_castVotesWithReason_arrayLengthMismatch() external {
        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _standardGovernor.castVotesWithReason(new uint256[](1), new uint8[](2), new string[](2));

        vm.expectRevert(abi.encodeWithSelector(IBatchGovernor.ArrayLengthMismatch.selector, 1, 2));

        vm.prank(_alice);
        _standardGovernor.castVotesWithReason(new uint256[](1), new uint8[](1), new string[](2));
    }

    function test_castVotesWithReason_emptyProposalIdsArray() external {
        vm.expectRevert(IBatchGovernor.EmptyProposalIdsArray.selector);

        vm.prank(_alice);
        _standardGovernor.castVotesWithReason(new uint256[](0), new uint8[](0), new string[](0));
    }

    /* ============ castVotesWithReasonBySig ============ */
    function test_castVotesWithReasonBySig() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch_);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch_);
        _standardGovernor.setNumberOfProposals(currentEpoch_, 2);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

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
        emit IGovernor.VoteCast(
            _alice,
            firstProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[0]
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(
            _alice,
            secondProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[1]
        );

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVotesWithReasonBySig(
                _alice,
                proposalIds_,
                supportList_,
                reasonList_,
                _getSignature(
                    _standardGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_),
                    _aliceKey
                )
            ),
            _votePower
        );
    }

    function test_castVotesWithReasonBySig_vrs() external {
        uint256 firstProposalId_ = 1;
        uint256 secondProposalId_ = 2;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposal(firstProposalId_, currentEpoch_);
        _standardGovernor.setProposal(secondProposalId_, currentEpoch_);
        _standardGovernor.setNumberOfProposals(currentEpoch_, 2);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

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
            _standardGovernor.getBallotsWithReasonDigest(proposalIds_, supportList_, reasonList_)
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(
            _alice,
            firstProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[0]
        );

        vm.expectEmit();
        emit IGovernor.VoteCast(
            _alice,
            secondProposalId_,
            uint8(IBatchGovernor.VoteType.Yes),
            _votePower,
            reasonList_[1]
        );

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch_);

        vm.prank(_alice);
        assertEq(
            _standardGovernor.castVotesWithReasonBySig(proposalIds_, supportList_, reasonList_, v_, r_, s_),
            _votePower
        );
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

    function test_propose_invalidValue() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        uint256[] memory values_ = new uint256[](1);
        values_[0] = 1;

        vm.expectRevert(IBatchGovernor.InvalidValue.selector);
        _standardGovernor.propose(targets_, values_, new bytes[](0), "");
    }

    function test_propose_invalidCallDatasLength() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        vm.expectRevert(IBatchGovernor.InvalidCallDatasLength.selector);
        _standardGovernor.propose(targets_, new uint256[](1), new bytes[](2), "");
    }

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

    function test_propose_uniqueProposalIds() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setProposalFee.selector, 1);

        _warpToNextTransferEpoch();

        uint256 proposalId1_ = _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "description 1");

        (address proposalCashToken_, uint256 proposalFee_) = _standardGovernor.getProposalFee(proposalId1_);
        assertEq(proposalFee_, _proposalFee);
        assertEq(proposalCashToken_, address(_cashToken));

        uint256 currentEpoch_ = _standardGovernor.clock();

        uint256 expectedProposalId1_ = uint256(
            keccak256(abi.encode(callDatas_[0], currentEpoch_ + 1, address(_standardGovernor)))
        );
        assertEq(proposalId1_, expectedProposalId1_);

        vm.expectRevert(IBatchGovernor.ProposalExists.selector);
        _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "description 2");

        _warpToNextVoteEpoch();

        uint256 proposalId2_ = _standardGovernor.propose(targets_, new uint256[](1), callDatas_, "description 1");
        assertNotEq(proposalId1_, proposalId2_);
    }

    function test_propose_invalidCallData() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.propose(targets_, new uint256[](1), new bytes[](1), "");
    }

    /* ============ state ============ */
    function test_state_pendingThenActive() external {
        uint256 proposalId_ = 1;
        uint256 nextEpoch = _standardGovernor.clock() + 1;

        _standardGovernor.setProposal(proposalId_, nextEpoch);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Pending));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));
    }

    function test_state_activeThenDefeatedNobodyVoted() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_state_activeThenDefeatedMajorityVotedNo() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.No));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_state_activeThenSucceededMajorityVotedYes() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));
    }

    function test_state_succeededThenExpired() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch, false, _alice, 0, 1);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Active));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Succeeded));

        _warpToNextEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Expired));
    }

    function test_state_executed() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch, true, _alice, 0, 1);

        assertEq(uint256(_standardGovernor.state(proposalId_)), uint256(IGovernor.ProposalState.Executed));
    }

    /* ============ execute ============ */
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

        vm.prank(_zeroGovernor);
        _standardGovernor.setCashToken(address(0), _proposalFee);
    }

    function test_setCashToken() external {
        address _cashToken2 = makeAddr("someCashToken");

        vm.expectEmit();
        emit IStandardGovernor.CashTokenSet(_cashToken2);

        vm.expectEmit();
        emit IStandardGovernor.ProposalFeeSet(_proposalFee * 2);

        vm.expectCall(address(_powerToken), abi.encodeCall(_powerToken.setNextCashToken, (_cashToken2)));

        vm.prank(_zeroGovernor);
        _standardGovernor.setCashToken(_cashToken2, _proposalFee * 2);

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

    function test_sendProposalFeeToVault_noFeeToSend() external {
        uint256 proposalId_ = 1;
        uint256 currentEpoch_ = _standardGovernor.clock();

        _standardGovernor.setProposalFeeInfo(proposalId_, address(_cashToken), 0);
        _standardGovernor.setProposal(proposalId_, currentEpoch_);

        _warpToNextVoteEpoch();

        vm.expectRevert(IStandardGovernor.NoFeeToSend.selector);
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
        assertEq(_standardGovernor.quorum(), 1);
        assertEq(_standardGovernor.quorum(1), 1);
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

    function test_addToList_callRegistrar() external {
        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.addToList, ("someList", _account1)));

        vm.prank(address(_standardGovernor));
        _standardGovernor.addToList("someList", _account1);
    }

    function test_addToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _standardGovernor.addToList("SOME_LIST", _alice);
    }

    /* ============ removeFromList ============ */
    function test_removeFromList_callRegistrar() external {
        vm.expectCall(address(_registrar), abi.encodeCall(_registrar.removeFromList, ("someList", _account1)));

        vm.prank(address(_standardGovernor));
        _standardGovernor.removeFromList("someList", _account1);
    }

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

    function test_revertIfInvalidCalldata_addToList() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_standardGovernor.addToList, ("someList", _account1)), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_removeFromList() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(
            abi.encodePacked(
                abi.encodeCall(_standardGovernor.removeFromList, ("someList", _account1)),
                "randomCalldata"
            )
        );
    }

    function test_revertIfInvalidCalldata_removeFromAndAddToList() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(
            abi.encodePacked(
                abi.encodeCall(_standardGovernor.removeFromAndAddToList, ("someList", _account1, _account1)),
                "randomCalldata"
            )
        );
    }

    function test_revertIfInvalidCalldata_setKey() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_standardGovernor.setKey, ("someList", "someKey")), "randomCalldata")
        );
    }

    function test_revertIfInvalidCalldata_setProposalFee() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _standardGovernor.revertIfInvalidCalldata(
            abi.encodePacked(abi.encodeCall(_standardGovernor.setProposalFee, (0)), "randomCalldata")
        );
    }
}
