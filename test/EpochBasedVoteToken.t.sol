// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC5805 } from "../src/abstract/interfaces/IERC5805.sol";

import { PureEpochs } from "../src/libs/PureEpochs.sol";

import { EpochBasedVoteTokenHarness as Vote } from "./utils/EpochBasedVoteTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

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

    function test_balanceOf() external {
        _vote.pushBalance(_alice, _vote.clock(), 13);

        assertEq(_vote.balanceOf(_alice), 13);
    }

    function test_pastBalanceOf_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastBalanceOf(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastBalanceOf(_alice, currentEpoch_ + 1);
    }

    function test_pastBalanceOf() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushBalance(_alice, currentEpoch_ - 4, 5);
        _vote.pushBalance(_alice, currentEpoch_ - 2, 13);

        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - 1), 13);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - 2), 13);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - 3), 5);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - 4), 5);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - 5), 0);
    }

    function test_delegates() external {
        _vote.pushDelegatee(_alice, _vote.clock(), _bob);

        assertEq(_vote.delegates(_alice), _bob);
    }

    function test_pastDelegates_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastDelegates(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastDelegates(_alice, currentEpoch_ + 1);
    }

    function test_pastDelegate() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushDelegatee(_alice, currentEpoch_ - 7, _carol);
        _vote.pushDelegatee(_alice, currentEpoch_ - 4, address(0));
        _vote.pushDelegatee(_alice, currentEpoch_ - 2, _bob);

        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 1), _bob);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 2), _bob);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 3), _alice);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 4), _alice);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 5), _carol);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 6), _carol);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 7), _carol);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 8), _alice);
    }

    function test_getVotes() external {
        _vote.pushVotes(_alice, _vote.clock(), 13);

        assertEq(_vote.getVotes(_alice), 13);
    }

    function test_getPastVotes_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.getPastVotes(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.getPastVotes(_alice, currentEpoch_ + 1);
    }

    function test_getPastVotes() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushVotes(_alice, currentEpoch_ - 4, 5);
        _vote.pushVotes(_alice, currentEpoch_ - 2, 13);

        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 1), 13);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 2), 13);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 3), 5);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 4), 5);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 5), 0);
    }

    function test_totalSupply() external {
        _vote.pushTotalSupply(_vote.clock(), 13);

        assertEq(_vote.totalSupply(), 13);
    }

    function test_pastTotalSupply_notPastEpoch() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _vote.pastTotalSupply(currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _vote.pastTotalSupply(currentEpoch_ + 1);
    }

    function test_pastTotalSupply() external {
        uint256 currentEpoch_ = _vote.clock();

        _vote.pushTotalSupply(currentEpoch_ - 4, 5);
        _vote.pushTotalSupply(currentEpoch_ - 2, 13);

        assertEq(_vote.pastTotalSupply(currentEpoch_ - 1), 13);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - 2), 13);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - 3), 5);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - 4), 5);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - 5), 0);
    }
}
