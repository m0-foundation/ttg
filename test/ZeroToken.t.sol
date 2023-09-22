// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";

import { ZeroToken } from "../src/ZeroToken.sol";

contract ZeroTokenTests is Test {
    address internal _registrar = makeAddr("registrar");

    ZeroToken internal _zeroToken;

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

    function setUp() external {
        _zeroToken = new ZeroToken(_registrar, _initialAccounts, _initialAmounts);
    }

    function test_initialState() external {
        assertEq(_zeroToken.registrar(), _registrar);

        for (uint256 index_; index_ < _initialAccounts.length; index_++) {
            assertEq(_zeroToken.balanceOf(_initialAccounts[index_]), _initialAmounts[index_]);
        }
    }
}
