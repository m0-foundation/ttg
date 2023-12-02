// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { console2 } from "../lib/forge-std/src/Test.sol";

import { IEpochBasedVoteToken } from "../src/abstract/interfaces/IEpochBasedVoteToken.sol";
import { IERC5805 } from "../src/abstract/interfaces/IERC5805.sol";

import { PureEpochs } from "../src/libs/PureEpochs.sol";

import { EpochBasedVoteTokenHarness as Vote } from "./utils/EpochBasedVoteTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_VotingPowerForDelegates

contract EpochBasedVoteTokenTests is TestUtils {
    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eric = makeAddr("eric");
    address internal _frank = makeAddr("frank");
    address internal _grace = makeAddr("grace");
    address internal _henry = makeAddr("henry");
    address internal _ivan = makeAddr("ivan");
    address internal _judy = makeAddr("judy");

    address[] internal _accounts = [_alice, _bob, _carol, _dave, _eric, _frank, _grace, _henry, _ivan, _judy];

    Vote internal _vote;

    function setUp() external {
        _vote = new Vote("Vote Epoch Token", "VOTE", 0);
    }

    function test_pastBalanceOf_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastBalanceOf(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastBalanceOf(_alice, currentEpoch_ + 1);
    }

    function test_pastBalancesOf_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastBalancesOf_startEpochAfterEndEpoch() external {
        vm.expectRevert(IEpochBasedVoteToken.StartEpochAfterEndEpoch.selector);
        _vote.pastBalancesOf(_alice, 1, 0);
    }

    function test_pastBalancesOf_subset() external {
        _jumpToEpoch(_vote.clock() + 20);

        uint256 currentEpoch_ = _vote.clock();

        _vote.pushBalance(_alice, currentEpoch_ - 10, 2);
        _vote.pushBalance(_alice, currentEpoch_ - 8, 10);
        _vote.pushBalance(_alice, currentEpoch_ - 7, 9);
        _vote.pushBalance(_alice, currentEpoch_ - 6, 5);
        _vote.pushBalance(_alice, currentEpoch_ - 2, 3);
        _vote.pushBalance(_alice, currentEpoch_, 7);

        uint256[] memory balances_ = _vote.pastBalancesOf(_alice, currentEpoch_ - 8, currentEpoch_ - 4);

        assertEq(balances_.length, 5);
        assertEq(balances_[0], 10);
        assertEq(balances_[1], 9);
        assertEq(balances_[2], 5);
        assertEq(balances_[3], 5);
        assertEq(balances_[4], 5);
    }

    function test_pastBalancesOf_single() external {
        _jumpToEpoch(_vote.clock() + 20);

        uint256 currentEpoch_ = _vote.clock();

        _vote.pushBalance(_alice, currentEpoch_ - 6, 5);
        _vote.pushBalance(_alice, currentEpoch_ - 2, 3);
        _vote.pushBalance(_alice, currentEpoch_, 7);

        uint256[] memory balances_ = _vote.pastBalancesOf(_alice, currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(balances_.length, 1);
        assertEq(balances_[0], 5);
    }

    function test_pastBalancesOf_beforeAllWindows() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushBalance(_alice, currentEpoch_ - 6, 5);
        _vote.pushBalance(_alice, currentEpoch_ - 2, 3);
        _vote.pushBalance(_alice, currentEpoch_, 7);

        uint256[] memory balances_ = _vote.pastBalancesOf(_alice, currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(balances_.length, 2);
        assertEq(balances_[0], 0);
        assertEq(balances_[0], 0);
    }

    function test_pastBalancesOf_afterAllWindows() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushBalance(_alice, currentEpoch_ - 10, 2);
        _vote.pushBalance(_alice, currentEpoch_ - 8, 10);
        _vote.pushBalance(_alice, currentEpoch_ - 7, 9);
        _vote.pushBalance(_alice, currentEpoch_ - 6, 5);

        uint256[] memory balances_ = _vote.pastBalancesOf(_alice, currentEpoch_ - 4, currentEpoch_ - 2);

        assertEq(balances_.length, 3);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
    }

    function test_pastDelegates_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastDelegates(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastDelegates(_alice, currentEpoch_ + 1);
    }

    function test_getPastVotes_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.getPastVotes(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.getPastVotes(_alice, currentEpoch_ + 1);
    }

    function test_pastTotalSupply_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastTotalSupply(currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastTotalSupply(currentEpoch_ + 1);
    }

    function test_pastTotalSupplies_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_ + 1);
    }
}
