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

    function test_pastBalanceOf_notPastTimepoint() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _vote.pastBalanceOf(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
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

    function test_pastDelegates_notPastTimepoint() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _vote.pastDelegates(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
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

    function test_getPastVotes_notPastTimepoint() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _vote.getPastVotes(_alice, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
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

    function test_pastTotalSupply_notPastTimepoint() external {
        uint256 currentEpoch_ = _vote.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _vote.pastTotalSupply(currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
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

    function test_delegatingToAddressZeroIsEquivalentToDelegatingToSelf() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        assertEq(_vote.delegates(_alice), _alice);

        vm.prank(_alice);
        _vote.transfer(_carol, 200);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 800);
        assertEq(_vote.balanceOf(_carol), 200);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 800);
        assertEq(_vote.getVotes(_carol), 200);

        vm.prank(_alice);
        _vote.delegate(address(0));

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 800);
        assertEq(_vote.balanceOf(_carol), 200);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 800);
        assertEq(_vote.getVotes(_carol), 200);

        vm.prank(_alice);
        _vote.transfer(_carol, 200);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 600);
        assertEq(_vote.balanceOf(_carol), 400);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 600);
        assertEq(_vote.getVotes(_carol), 400);

        vm.prank(_alice);
        _vote.delegate(_alice);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 600);
        assertEq(_vote.balanceOf(_carol), 400);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 600);
        assertEq(_vote.getVotes(_carol), 400);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _bob);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 600);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 400);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 600);
        assertEq(_vote.getVotes(_carol), 400);

        vm.prank(_alice);
        _vote.transfer(_carol, 200);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _bob);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 400);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 600);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 400);
        assertEq(_vote.getVotes(_carol), 600);

        vm.prank(_alice);
        _vote.delegate(address(0));

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 400);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 600);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 400);
        assertEq(_vote.getVotes(_bob), 0);
        assertEq(_vote.getVotes(_carol), 600);

        vm.prank(_alice);
        _vote.transfer(_carol, 200);

        assertEq(_vote.delegates(address(0)), address(0));
        assertEq(_vote.delegates(_alice), _alice);
        assertEq(_vote.delegates(_carol), _carol);

        assertEq(_vote.balanceOf(address(0)), 0);
        assertEq(_vote.balanceOf(_alice), 200);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 800);

        assertEq(_vote.getVotes(address(0)), 0);
        assertEq(_vote.getVotes(_alice), 200);
        assertEq(_vote.getVotes(_bob), 0);
        assertEq(_vote.getVotes(_carol), 800);
    }
}
