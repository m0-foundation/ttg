// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Test } from "../lib/forge-std/src/Test.sol";

import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";

import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";

contract DeployerTests is Test {
    address internal _cashToken = makeAddr("cashToken");
    address internal _governor = makeAddr("governor");
    address internal _powerToken = makeAddr("powerToken");
    address internal _registrar = makeAddr("registrar");
    address internal _vault = makeAddr("vault");

    DualGovernorDeployer internal _governorDeployer;
    MockEpochBasedVoteToken internal _zeroToken;

    function setUp() external {
        _zeroToken = new MockEpochBasedVoteToken();
        _governorDeployer = new DualGovernorDeployer(_registrar, _vault, address(_zeroToken));
    }

    function test_deployAddress() external {
        address nextDeploy_ = _governorDeployer.getNextDeploy();

        vm.prank(_registrar);
        address deployed_ = _governorDeployer.deploy(_cashToken, _powerToken, 0, 0, 0, 0, 0, 0);

        assertEq(deployed_, nextDeploy_);
    }
}
