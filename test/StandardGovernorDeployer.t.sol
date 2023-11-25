// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "../lib/forge-std/src/Test.sol";

import { StandardGovernorDeployer } from "../src/StandardGovernorDeployer.sol";

contract StandardGovernorDeployerTests is Test {
    address internal _registrar = makeAddr("registrar");
    address internal _vault = makeAddr("vault");
    address internal _zeroGovernor = makeAddr("zeroGovernor");
    address internal _zeroToken = makeAddr("zeroToken");

    StandardGovernorDeployer internal _deployer;

    function setUp() external {
        _deployer = new StandardGovernorDeployer(_registrar, _vault, _zeroGovernor, _zeroToken);
    }

    function test_initialState() external {
        assertEq(_deployer.registrar(), _registrar);
        assertEq(_deployer.vault(), _vault);
        assertEq(_deployer.zeroGovernor(), _zeroGovernor);
        assertEq(_deployer.zeroToken(), _zeroToken);
        assertEq(_deployer.nonce(), 0);
    }

    function test_deployAddress() external {
        address nextDeploy_ = _deployer.getNextDeploy();

        vm.prank(_registrar);
        address deployed_ = _deployer.deploy(
            makeAddr("voteToken"),
            makeAddr("emergencyGovernor"),
            makeAddr("cashToken"),
            1,
            1
        );

        assertEq(deployed_, nextDeploy_);
    }
}
