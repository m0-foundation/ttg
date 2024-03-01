// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../../src/abstract/interfaces/IBatchGovernor.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IGovernor } from "../../src/abstract/interfaces/IGovernor.sol";

import { StandardGovernorHarness } from "./../utils/StandardGovernorHarness.sol";
import { MockERC20, MockPowerToken, MockRegistrar, MockZeroToken } from "./../utils/Mocks.sol";
import { TestUtils } from "./../utils/TestUtils.sol";

contract StandardGovernorTests is TestUtils {
    uint256 internal constant _ONE = 10_000;

    address internal _alice = makeAddr("alice");
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

    function testFuzz_castVote_votedOnFirstOfSeveralProposals(
        uint8 proposalId_,
        uint8 totalNumberOfProposals
    ) external {
        totalNumberOfProposals = uint8(bound(totalNumberOfProposals, 2, type(uint8).max));
        proposalId_ = uint8(bound(proposalId_, 1, totalNumberOfProposals));
        uint256 currentEpoch = _standardGovernor.clock();

        _standardGovernor.setProposal(proposalId_, currentEpoch);
        _standardGovernor.setNumberOfProposals(currentEpoch, totalNumberOfProposals);

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(1);

        vm.expectEmit();
        emit IGovernor.VoteCast(_alice, proposalId_, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes)), _votePower);

        assertEq(_standardGovernor.numberOfProposalsVotedOnAt(_alice, currentEpoch), 1);
    }

    /* ============ castVotes ============ */
    function testFuzz_castVotes(uint256 numberOfProposals) external {
        numberOfProposals = uint8(bound(numberOfProposals, 1, type(uint8).max));

        uint256[] memory proposalIds_ = new uint256[](numberOfProposals);
        uint8[] memory supports_ = new uint8[](numberOfProposals);
        uint256 proposalId;

        uint256 currentEpoch = _standardGovernor.clock();

        _powerToken.setVotePower(_votePower);
        _powerToken.setPastTotalSupply(_votePower);
        _standardGovernor.setNumberOfProposals(currentEpoch, numberOfProposals);

        for (proposalId; proposalId < numberOfProposals; ++proposalId) {
            _standardGovernor.setProposal(proposalId, currentEpoch);

            proposalIds_[proposalId] = proposalId;
            supports_[proposalId] = uint8(IBatchGovernor.VoteType.Yes);
        }

        for (proposalId = 0; proposalId < numberOfProposals; ++proposalId) {
            vm.expectEmit();
            emit IGovernor.VoteCast(_alice, proposalId, uint8(IBatchGovernor.VoteType.Yes), _votePower, "");
        }

        vm.expectEmit();
        emit IStandardGovernor.HasVotedOnAllProposals(_alice, currentEpoch);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVotes(proposalIds_, supports_), _votePower);
    }
}
