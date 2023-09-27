// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Test } from "../lib/forge-std/src/Test.sol";

import { Deploy } from "../script/Deploy.s.sol";

contract DualGovernorTests is Test {
    Deploy internal _deploy;

    function setUp() external {
        _deploy = new Deploy();
    }

    function test_initialState() external {
        _deploy.run();
    }
}
