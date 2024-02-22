// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC5805 } from "../../src/abstract/interfaces/IERC5805.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

import { EpochBasedVoteTokenHarness as Vote } from "./../utils/EpochBasedVoteTokenHarness.sol";
import { TestUtils } from "./../utils/TestUtils.sol";

contract EpochBasedVoteTokenFuzzTests is TestUtils {
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

    function testFuzz_pastBalanceOf(
        uint8 firstPushEpoch,
        uint8 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 currentEpoch_ = _vote.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 1));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);

        vm.assume(currentEpoch_ - firstPushEpoch - 1 != 0);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _vote.pushBalance(_alice, currentEpoch_ - firstPushEpoch, firstValuePushed);
        _vote.pushBalance(_alice, currentEpoch_ - secondPushEpoch, secondValuePushed);

        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - firstPushEpoch), firstValuePushed);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - firstPushEpoch - 1), 0);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - secondPushEpoch), secondValuePushed);
        assertEq(_vote.pastBalanceOf(_alice, currentEpoch_ - secondPushEpoch - 1), firstValuePushed);
    }

    function testFuzz_pastDelegate(uint8 firstPushEpoch, uint8 secondPushEpoch, uint8 thirdPushEpoch) external {
        uint256 currentEpoch_ = _vote.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 1));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        thirdPushEpoch = uint8(bound(thirdPushEpoch, 1, currentEpoch_ - 1));
        vm.assume(firstPushEpoch > secondPushEpoch && secondPushEpoch > thirdPushEpoch);

        _vote.pushDelegatee(_alice, currentEpoch_ - firstPushEpoch, _carol);
        _vote.pushDelegatee(_alice, currentEpoch_ - secondPushEpoch, address(0));
        _vote.pushDelegatee(_alice, currentEpoch_ - thirdPushEpoch, _bob);

        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - firstPushEpoch), _carol);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - secondPushEpoch - 1), _carol);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - secondPushEpoch), _alice);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - thirdPushEpoch - 1), _alice);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - thirdPushEpoch), _bob);
        assertEq(_vote.pastDelegates(_alice, currentEpoch_ - 1), _bob);
    }

    function testFuzz_getPastVotes(
        uint8 firstPushEpoch,
        uint8 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 currentEpoch_ = _vote.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 1));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);

        vm.assume(currentEpoch_ - firstPushEpoch - 1 != 0);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _vote.pushVotes(_alice, currentEpoch_ - firstPushEpoch, firstValuePushed);
        _vote.pushVotes(_alice, currentEpoch_ - secondPushEpoch, secondValuePushed);

        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - firstPushEpoch - 1), 0);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - firstPushEpoch), firstValuePushed);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - secondPushEpoch - 1), firstValuePushed);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - secondPushEpoch), secondValuePushed);
        assertEq(_vote.getPastVotes(_alice, currentEpoch_ - 1), secondValuePushed);
    }

    function testFuzz_pastTotalSupply(
        uint8 firstPushEpoch,
        uint8 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 currentEpoch_ = _vote.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 1));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);

        vm.assume(currentEpoch_ - firstPushEpoch - 1 != 0);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _vote.pushTotalSupply(currentEpoch_ - firstPushEpoch, firstValuePushed);
        _vote.pushTotalSupply(currentEpoch_ - secondPushEpoch, secondValuePushed);

        assertEq(_vote.pastTotalSupply(currentEpoch_ - firstPushEpoch - 1), 0);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - firstPushEpoch), firstValuePushed);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - secondPushEpoch - 1), firstValuePushed);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - secondPushEpoch), secondValuePushed);
        assertEq(_vote.pastTotalSupply(currentEpoch_ - 1), secondValuePushed);
    }
}
