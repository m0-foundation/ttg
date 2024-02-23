// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC5805 } from "../../src/abstract/interfaces/IERC5805.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";

import { TestUtils } from "./../utils/TestUtils.sol";
import { ZeroTokenHarness } from "./../utils/ZeroTokenHarness.sol";

contract ZeroTokenFuzzTests is TestUtils {
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

    function testFuzz_pastBalancesOf_subset(
        uint256 firstPushEpoch,
        uint256 secondPushEpoch,
        uint256 thirdPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed,
        uint256 thirdValuePushed
    ) external {
        uint256 currentEpoch_ = _zeroToken.clock();

        _warpToEpoch(currentEpoch_);

        firstPushEpoch = bound(firstPushEpoch, 1, currentEpoch_ - 1);
        secondPushEpoch = bound(secondPushEpoch, 1, currentEpoch_ - 1);
        thirdPushEpoch = bound(thirdPushEpoch, 1, currentEpoch_ - 1);
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);
        thirdValuePushed = bound(thirdValuePushed, 0, type(uint128).max);
        vm.assume(firstPushEpoch > secondPushEpoch && secondPushEpoch > thirdPushEpoch);

        _zeroToken.pushBalance(_alice, currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushBalance(_alice, currentEpoch_ - secondPushEpoch, secondValuePushed);
        _zeroToken.pushBalance(_alice, currentEpoch_ - thirdPushEpoch, thirdValuePushed);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(
            _alice,
            currentEpoch_ - firstPushEpoch,
            currentEpoch_ - thirdPushEpoch
        );

        assertEq(balances_[0], firstValuePushed);
        assertEq(balances_[firstPushEpoch - secondPushEpoch - 1], firstValuePushed);
        assertEq(balances_[firstPushEpoch - secondPushEpoch], secondValuePushed);
        assertEq(balances_[firstPushEpoch - thirdPushEpoch - 1], secondValuePushed);
        assertEq(balances_[firstPushEpoch - thirdPushEpoch], thirdValuePushed);
    }

    function testFuzz_pastBalancesOf_beforeAllSnaps(
        uint8 warpEpoch,
        uint256 firstPushEpoch,
        uint256 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 clock_ = _zeroToken.clock();
        uint256 currentEpoch_ = clock_ + warpEpoch;

        _warpToEpoch(currentEpoch_);

        firstPushEpoch = bound(firstPushEpoch, 1, currentEpoch_ - 1);
        secondPushEpoch = bound(secondPushEpoch, 1, currentEpoch_);
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);

        vm.assume(currentEpoch_ - firstPushEpoch - 1 != 0);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _zeroToken.pushBalance(_alice, currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushBalance(_alice, currentEpoch_ - secondPushEpoch, secondValuePushed);

        uint256[] memory balances_ = _zeroToken.pastBalancesOf(
            _alice,
            currentEpoch_ - firstPushEpoch - 1,
            currentEpoch_ - 1
        );

        assertEq(balances_[0], 0);
    }

    function testFuzz_pastBalancesOf_afterAllSnaps(
        uint8 warpEpoch,
        uint256 firstPushEpoch,
        uint256 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 clock_ = _zeroToken.clock();
        uint256 currentEpoch_ = clock_ + warpEpoch;

        _warpToEpoch(currentEpoch_);

        firstPushEpoch = bound(firstPushEpoch, 1, currentEpoch_ - 1);
        secondPushEpoch = bound(secondPushEpoch, 1, currentEpoch_);
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _zeroToken.pushBalance(_alice, currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushBalance(_alice, currentEpoch_ - secondPushEpoch, secondValuePushed);

        _warpToEpoch(currentEpoch_ + 2);
        uint256[] memory balances_ = _zeroToken.pastBalancesOf(
            _alice,
            currentEpoch_ - secondPushEpoch + 1,
            currentEpoch_
        );

        assertEq(balances_[0], secondValuePushed);
    }

    function testFuzz_pastTotalSupplies_subset(
        uint256 firstPushEpoch,
        uint256 secondPushEpoch,
        uint256 thirdPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed,
        uint256 thirdValuePushed
    ) external {
        uint256 currentEpoch_ = _zeroToken.clock();

        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 3));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        thirdPushEpoch = uint8(bound(thirdPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);
        thirdValuePushed = bound(thirdValuePushed, 0, type(uint128).max);
        vm.assume(firstPushEpoch > secondPushEpoch && secondPushEpoch > thirdPushEpoch);

        _zeroToken.pushTotalSupply(currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushTotalSupply(currentEpoch_ - secondPushEpoch, secondValuePushed);
        _zeroToken.pushTotalSupply(currentEpoch_ - thirdPushEpoch, thirdValuePushed);

        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(
            currentEpoch_ - firstPushEpoch,
            currentEpoch_ - thirdPushEpoch - 1
        );

        assertEq(totalSupplies_[0], firstValuePushed);
        assertEq(totalSupplies_[firstPushEpoch - secondPushEpoch - 1], firstValuePushed);
        assertEq(totalSupplies_[firstPushEpoch - secondPushEpoch], secondValuePushed);
        assertEq(totalSupplies_[firstPushEpoch - thirdPushEpoch - 1], secondValuePushed);
    }

    function testFuzz_pastTotalSupplies_beforeAllSnaps(
        uint8 firstPushEpoch,
        uint8 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 currentEpoch_ = _zeroToken.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 3));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _zeroToken.pushTotalSupply(currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushTotalSupply(currentEpoch_ - secondPushEpoch, secondValuePushed);

        _warpToEpoch(_zeroToken.clock() + 20);
        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(
            currentEpoch_ - firstPushEpoch - 2,
            currentEpoch_ - firstPushEpoch - 1
        );

        assertEq(totalSupplies_[0], 0);
        assertEq(totalSupplies_[0], 0);
    }

    function testFuzz_pastTotalSupplies_afterAllSnaps(
        uint8 firstPushEpoch,
        uint8 secondPushEpoch,
        uint256 firstValuePushed,
        uint256 secondValuePushed
    ) external {
        uint256 currentEpoch_ = _zeroToken.clock();
        firstPushEpoch = uint8(bound(firstPushEpoch, 1, currentEpoch_ - 3));
        secondPushEpoch = uint8(bound(secondPushEpoch, 1, currentEpoch_ - 1));
        firstValuePushed = bound(firstValuePushed, 0, type(uint128).max);
        secondValuePushed = bound(secondValuePushed, 0, type(uint128).max);
        vm.assume(firstPushEpoch > secondPushEpoch);

        _zeroToken.pushTotalSupply(currentEpoch_ - firstPushEpoch, firstValuePushed);
        _zeroToken.pushTotalSupply(currentEpoch_ - secondPushEpoch, secondValuePushed);

        _warpToEpoch(_zeroToken.clock() + 20);
        uint256[] memory totalSupplies_ = _zeroToken.pastTotalSupplies(currentEpoch_, currentEpoch_ + 1);

        assertEq(totalSupplies_[0], secondValuePushed);
        assertEq(totalSupplies_[1], secondValuePushed);
    }
}
