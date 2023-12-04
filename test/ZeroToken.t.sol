// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC5805 } from "../src/abstract/interfaces/IERC5805.sol";
import { IZeroToken } from "../src/interfaces/IZeroToken.sol";

import { TestUtils } from "./utils/TestUtils.sol";
import { ZeroTokenHarness } from "./utils/ZeroTokenHarness.sol";

contract ZeroTokenTests is TestUtils {
    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _standardGovernorDeployer = makeAddr("standardGovernorDeployer");

    ZeroTokenHarness internal _zeroToken;

    address[] internal _initialAccounts = [
        makeAddr("account1"),
        makeAddr("account2"),
        makeAddr("account3"),
        makeAddr("account4"),
        makeAddr("account5")
    ];

    uint256[] internal _initialAmounts = [
        1_000_000 * 1e6,
        2_000_000 * 1e6,
        3_000_000 * 1e6,
        4_000_000 * 1e6,
        5_000_000 * 1e6
    ];

    uint256[] internal _claimableEpochs;

    function setUp() external {
        _zeroToken = new ZeroTokenHarness(_standardGovernorDeployer, _initialAccounts, _initialAmounts);
    }

    function test_initialState() external {
        assertEq(_zeroToken.standardGovernorDeployer(), _standardGovernorDeployer);

        for (uint256 index_; index_ < _initialAccounts.length; index_++) {
            assertEq(_zeroToken.balanceOf(_initialAccounts[index_]), _initialAmounts[index_]);
        }
    }

    function test_pastBalancesOf_notPastEpoch() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastBalancesOf_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.pastBalancesOf(_alice, 1, 0);
    }

    function test_pastBalancesOf_subset() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 10, 2);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 8, 10);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 7, 9);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 8, currentEpoch_ - 4);

        assertEq(balances_.length, 5);
        assertEq(balances_[0], 10);
        assertEq(balances_[1], 9);
        assertEq(balances_[2], 5);
        assertEq(balances_[3], 5);
        assertEq(balances_[4], 5);
    }

    function test_pastBalancesOf_single() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(balances_.length, 1);
        assertEq(balances_[0], 5);
    }

    function test_pastBalancesOf_beforeAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(balances_.length, 2);
        assertEq(balances_[0], 0);
        assertEq(balances_[0], 0);
    }

    function test_pastBalancesOf_afterAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 10, 2);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 8, 10);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 7, 9);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 4, currentEpoch_ - 2);

        assertEq(balances_.length, 3);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
    }

    function test_pastDelegates_multi_notPastEpoch() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _zeroToken.pastDelegates(_alice, currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.pastDelegates(_alice, currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastDelegates_multi_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.pastDelegates(_alice, 1, 0);
    }

    function test_pastDelegates_multi_subset() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 7, _carol);
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 4, address(0));
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 2, _bob);

        address[] memory delegatees_ = _zeroToken.pastDelegates(_alice, currentEpoch_ - 6, currentEpoch_ - 2);

        assertEq(delegatees_.length, 5);
        assertEq(delegatees_[0], _carol);
        assertEq(delegatees_[1], _carol);
        assertEq(delegatees_[2], _alice);
        assertEq(delegatees_[3], _alice);
        assertEq(delegatees_[4], _bob);
    }

    function test_pastDelegates_multi_single() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 7, _carol);
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 4, address(0));
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 2, _bob);

        address[] memory delegatees_ = _zeroToken.pastDelegates(_alice, currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(delegatees_.length, 1);
        assertEq(delegatees_[0], _alice);
    }

    function test_pastDelegates_multi_beforeAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 7, _carol);
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 4, address(0));
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 2, _bob);

        address[] memory delegatees_ = _zeroToken.pastDelegates(_alice, currentEpoch_ - 9, currentEpoch_ - 8);

        assertEq(delegatees_.length, 2);
        assertEq(delegatees_[0], _alice);
        assertEq(delegatees_[1], _alice);
    }

    function test_pastDelegates_multi_afterAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 7, _carol);
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 4, address(0));
        _zeroToken.pushDelegatee(_alice, currentEpoch_ - 2, _bob);

        address[] memory delegatees_ = _zeroToken.pastDelegates(_alice, currentEpoch_ - 3, currentEpoch_ - 1);

        assertEq(delegatees_.length, 3);
        assertEq(delegatees_[0], _alice);
        assertEq(delegatees_[1], _bob);
        assertEq(delegatees_[2], _bob);
    }

    function test_getPastVotes_multi_notPastEpoch() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _zeroToken.getPastVotes(_alice, currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.getPastVotes(_alice, currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_getPastVotes_multi_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.getPastVotes(_alice, 1, 0);
    }

    function test_getPastVotes_multi_subset() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushVotes(_alice, currentEpoch_ - 10, 2);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 8, 10);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 7, 9);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.getPastVotes(_alice, currentEpoch_ - 8, currentEpoch_ - 4);

        assertEq(balances_.length, 5);
        assertEq(balances_[0], 10);
        assertEq(balances_[1], 9);
        assertEq(balances_[2], 5);
        assertEq(balances_[3], 5);
        assertEq(balances_[4], 5);
    }

    function test_getPastVotes_multi_single() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushVotes(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.getPastVotes(_alice, currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(balances_.length, 1);
        assertEq(balances_[0], 5);
    }

    function test_getPastVotes_multi_beforeAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushVotes(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.getPastVotes(_alice, currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(balances_.length, 2);
        assertEq(balances_[0], 0);
        assertEq(balances_[0], 0);
    }

    function test_getPastVotes_multi_afterAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushVotes(_alice, currentEpoch_ - 10, 2);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 8, 10);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 7, 9);
        _zeroToken.pushVotes(_alice, currentEpoch_ - 6, 5);

        uint256[] memory balances_ = _zeroToken.getPastVotes(_alice, currentEpoch_ - 4, currentEpoch_ - 2);

        assertEq(balances_.length, 3);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
        assertEq(balances_[0], 5);
    }

    function test_pastTotalSupplies_notPastEpoch() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_, currentEpoch_));
        _zeroToken.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastEpoch.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastTotalSupplies_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.pastTotalSupplies(1, 0);
    }

    function test_pastTotalSupplies_subset() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 10, 2);
        _zeroToken.pushTotalSupply(currentEpoch_ - 8, 10);
        _zeroToken.pushTotalSupply(currentEpoch_ - 7, 9);
        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);
        _zeroToken.pushTotalSupply(currentEpoch_ - 2, 3);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 8, currentEpoch_ - 4);

        assertEq(totalSupplies_.length, 5);
        assertEq(totalSupplies_[0], 10);
        assertEq(totalSupplies_[1], 9);
        assertEq(totalSupplies_[2], 5);
        assertEq(totalSupplies_[3], 5);
        assertEq(totalSupplies_[4], 5);
    }

    function test_pastTotalSupplies_single() external {
        _jumpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);
        _zeroToken.pushTotalSupply(currentEpoch_ - 2, 3);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(totalSupplies_.length, 1);
        assertEq(totalSupplies_[0], 5);
    }

    function test_pastTotalSupplies_beforeAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);
        _zeroToken.pushTotalSupply(currentEpoch_ - 2, 3);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(totalSupplies_.length, 2);
        assertEq(totalSupplies_[0], 0);
        assertEq(totalSupplies_[0], 0);
    }

    function test_pastTotalSupplies_afterAllWindows() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 10, 2);
        _zeroToken.pushTotalSupply(currentEpoch_ - 8, 10);
        _zeroToken.pushTotalSupply(currentEpoch_ - 7, 9);
        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 4, currentEpoch_ - 2);

        assertEq(totalSupplies_.length, 3);
        assertEq(totalSupplies_[0], 5);
        assertEq(totalSupplies_[0], 5);
        assertEq(totalSupplies_[0], 5);
    }
}
