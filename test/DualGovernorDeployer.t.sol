// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";

import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";

import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";

contract DeployerTests is Test {
    address internal _cash = makeAddr("cash");
    address internal _governor = makeAddr("governor");
    address internal _registrar = makeAddr("registrar");
    address internal _powerToken = makeAddr("powerToken");

    DualGovernorDeployer internal _dualGovernorDeployer;
    MockEpochBasedVoteToken internal _zeroToken;

    function setUp() external {
        _zeroToken = new MockEpochBasedVoteToken();
        _dualGovernorDeployer = new DualGovernorDeployer(_registrar, address(_zeroToken));
    }

    function test_deployAddress() external {
        address nextDeploy_ = _dualGovernorDeployer.getNextDeploy();

        vm.prank(_registrar);
        address deployed_ = _dualGovernorDeployer.deploy(_cash, _powerToken, 0, 0, 0, 0, 0, 0);

        assertEq(deployed_, nextDeploy_);
    }
}
