// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IPowerToken } from "../../../src/interfaces/IPowerToken.sol";
import { IZeroToken } from "../../../src/interfaces/IZeroToken.sol";

import { IntegrationBaseSetup } from "../IntegrationBaseSetup.t.sol";

contract StandardGovernorSetKey_IntegrationTest is IntegrationBaseSetup {
    function test_initialState() external {
        IPowerToken powerToken_ = IPowerToken(_registrar.powerToken());
        uint256 initialPowerTotalSupply_;

        for (uint256 index_; index_ < _initialBalances[0].length; ++index_) {
            initialPowerTotalSupply_ += _initialBalances[0][index_];
        }

        for (uint256 index_; index_ < _initialAccounts[0].length; ++index_) {
            assertEq(
                powerToken_.balanceOf(_initialAccounts[0][index_]),
                (_initialBalances[0][index_] * powerToken_.INITIAL_SUPPLY()) / initialPowerTotalSupply_
            );
        }

        IZeroToken zeroToken_ = IZeroToken(_registrar.zeroToken());

        for (uint256 index_; index_ < _initialAccounts[1].length; ++index_) {
            assertEq(zeroToken_.balanceOf(_initialAccounts[1][index_]), _initialBalances[1][index_]);
        }
    }
}
