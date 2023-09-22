// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";

import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";

import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";

contract DeployerTests is Test {
    address internal _cash = makeAddr("cash");
    address internal _governor = makeAddr("governor");
    address internal _registrar = makeAddr("registrar");
    address internal _treasury = makeAddr("treasury");

    PowerTokenDeployer internal _powerTokenDeployer;
    MockEpochBasedVoteToken internal _zeroToken;

    function setUp() external {
        _zeroToken = new MockEpochBasedVoteToken();
        _powerTokenDeployer = new PowerTokenDeployer(_registrar, _treasury, address(_zeroToken));
    }

    function test_deployAddress() external {
        address nextDeploy_ = _powerTokenDeployer.getNextDeploy();

        vm.prank(_registrar);
        address deployed_ = _powerTokenDeployer.deploy(_governor, _cash);

        assertEq(deployed_, nextDeploy_);
    }
}
