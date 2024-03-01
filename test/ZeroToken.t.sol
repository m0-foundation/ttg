// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC5805 } from "../src/abstract/interfaces/IERC5805.sol";
import { IEpochBasedVoteToken } from "../src/abstract/interfaces/IEpochBasedVoteToken.sol";
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

    /* ============ pastBalancesOf ============ */
    function test_pastBalancesOf_notPastTimepoint() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastBalancesOf_epochZero() external {
        vm.expectRevert(IEpochBasedVoteToken.EpochZero.selector);
        _zeroToken.pastBalancesOf(_alice, 0, 1);
    }

    function test_pastBalancesOf_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.pastBalancesOf(_alice, 1, 0);
    }

    function test_pastBalancesOf_subset() external {
        _warpToEpoch(_zeroToken.clock() + 20);

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
        _warpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(balances_.length, 1);
        assertEq(balances_[0], 5);
    }

    function test_pastBalancesOf_beforeAllSnaps() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushBalance(_alice, currentEpoch_ - 6, 5);
        _zeroToken.pushBalance(_alice, currentEpoch_ - 2, 3);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(_alice, currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(balances_.length, 2);
        assertEq(balances_[0], 0);
        assertEq(balances_[0], 0);
    }

    function test_pastBalancesOf_afterAllSnaps() external {
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

    function test_pastTotalSupplies_notPastTimepoint() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_, currentEpoch_));
        _zeroToken.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_);

        vm.expectRevert(abi.encodeWithSelector(IERC5805.NotPastTimepoint.selector, currentEpoch_ + 1, currentEpoch_));
        _zeroToken.pastTotalSupplies(currentEpoch_ - 1, currentEpoch_ + 1);
    }

    function test_pastTotalSupplies_EpochZero() external {
        vm.expectRevert(IEpochBasedVoteToken.EpochZero.selector);
        _zeroToken.pastTotalSupplies(0, 1);
    }

    function test_pastTotalSupplies_startEpochAfterEndEpoch() external {
        vm.expectRevert(IZeroToken.StartEpochAfterEndEpoch.selector);
        _zeroToken.pastTotalSupplies(1, 0);
    }

    function test_pastTotalSupplies_subset() external {
        _warpToEpoch(_zeroToken.clock() + 20);

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
        _warpToEpoch(_zeroToken.clock() + 20);

        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);
        _zeroToken.pushTotalSupply(currentEpoch_ - 2, 3);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 4, currentEpoch_ - 4);

        assertEq(totalSupplies_.length, 1);
        assertEq(totalSupplies_[0], 5);
    }

    function test_pastTotalSupplies_beforeAllSnaps() external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _zeroToken.pushTotalSupply(currentEpoch_ - 6, 5);
        _zeroToken.pushTotalSupply(currentEpoch_ - 2, 3);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_ - 8, currentEpoch_ - 7);

        assertEq(totalSupplies_.length, 2);
        assertEq(totalSupplies_[0], 0);
        assertEq(totalSupplies_[0], 0);
    }

    function test_pastTotalSupplies_afterAllSnaps() external {
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
