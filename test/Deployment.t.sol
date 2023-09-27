// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IPowerToken } from "../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { Deploy } from "../script/Deploy.s.sol";

contract DualGovernorTests is Test {
    Deploy internal _deploy;

    function setUp() external {
        _deploy = new Deploy();
    }

    function test_initialState() external {
        _deploy.run();

        address powerToken_ = IDualGovernor(IRegistrar(_deploy.registrar()).governor()).powerToken();

        for (uint256 index_; index_ < _deploy.initialPowerAccountCount(); ++index_) {
            assertEq(
                IPowerToken(powerToken_).balanceOf(_deploy.initialPowerAccounts(index_)),
                (_deploy.initialPowerBalances(index_) * IPowerToken(powerToken_).INITIAL_SUPPLY()) /
                    _deploy.initialPowerTotalSupply()
            );
        }
    }
}
