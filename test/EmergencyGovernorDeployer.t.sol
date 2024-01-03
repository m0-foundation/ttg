// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IEmergencyGovernorDeployer } from "../src/interfaces/IEmergencyGovernorDeployer.sol";

import { EmergencyGovernorDeployer } from "../src/EmergencyGovernorDeployer.sol";

contract EmergencyGovernorDeployerTests is Test {
    address internal _registrar = makeAddr("registrar");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    EmergencyGovernorDeployer internal _deployer;

    function setUp() external {
        _deployer = new EmergencyGovernorDeployer(_zeroGovernor, _registrar);
    }

    function test_initialState() external {
        assertEq(_deployer.registrar(), _registrar);
        assertEq(_deployer.zeroGovernor(), _zeroGovernor);
        assertEq(_deployer.nonce(), 0);
    }

    function test_deployAddress_notZeroGovernor() external {
        vm.expectRevert(IEmergencyGovernorDeployer.NotZeroGovernor.selector);
        _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), 1);
    }

    function test_deployAddress() external {
        address nextDeploy_ = _deployer.nextDeploy();

        vm.prank(_zeroGovernor);
        address deployed_ = _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), 8000);

        assertEq(deployed_, nextDeploy_);
    }
}
