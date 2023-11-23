// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "../lib/forge-std/src/Test.sol";

import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";

import { MockEpochBasedVoteToken } from "./utils/Mocks.sol";

contract DeployerTests is Test {
    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");
    address internal _governor = makeAddr("governor");
    address internal _powerToken = makeAddr("powerToken");
    address internal _registrar = makeAddr("registrar");
    address internal _vault = makeAddr("vault");

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    DualGovernorDeployer internal _governorDeployer;
    MockEpochBasedVoteToken internal _zeroToken;

    function setUp() external {
        _zeroToken = new MockEpochBasedVoteToken();
        _governorDeployer = new DualGovernorDeployer(_registrar, _vault, address(_zeroToken), _allowedCashTokens);
    }

    function test_deployAddress() external {
        address nextDeploy_ = _governorDeployer.getNextDeploy();

        vm.prank(_registrar);
        address deployed_ = _governorDeployer.deploy(_powerToken, 0, 0, 0, 0);

        assertEq(deployed_, nextDeploy_);
    }
}
