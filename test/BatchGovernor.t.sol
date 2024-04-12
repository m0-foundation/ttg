// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IGovernor } from "../src/abstract/interfaces/IGovernor.sol";

import { BatchGovernorHarness } from "./utils/BatchGovernorHarness.sol";
import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract BatchGovernorTests is TestUtils {
    address internal _alice;
    uint256 internal _aliceKey;

    BatchGovernorHarness internal _batchGovernor;

    MockEpochBasedVoteToken internal _voteToken;

    function setUp() external {
        (_alice, _aliceKey) = makeAddrAndKey("alice");

        _voteToken = new MockEpochBasedVoteToken();
        _batchGovernor = new BatchGovernorHarness("BatchGovernor", address(_voteToken));
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

        vm.prank(_alice);
        _batchGovernor.castVote(proposalId_, uint8(IBatchGovernor.VoteType.Yes));

        assertFalse(_batchGovernor.hasVoted(proposalId_, _alice));
    }
}
