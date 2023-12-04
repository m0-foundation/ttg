// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IPowerTokenDeployer } from "../src/interfaces/IPowerTokenDeployer.sol";

import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";

import { MockBootstrapToken } from "./utils/Mocks.sol";

contract DeployerTests is Test {
    address internal _vault = makeAddr("vault");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    PowerTokenDeployer internal _powerTokenDeployer;
    MockBootstrapToken internal _bootstrapToken;

    function setUp() external {
        _powerTokenDeployer = new PowerTokenDeployer(_zeroGovernor, _vault);
        _bootstrapToken = new MockBootstrapToken();

        _bootstrapToken.setTotalSupply(1);
    }

    function test_initialState() external {
        assertEq(_powerTokenDeployer.vault(), _vault);
        assertEq(_powerTokenDeployer.zeroGovernor(), _zeroGovernor);
        assertEq(_powerTokenDeployer.nonce(), 0);
    }

    function test_deployAddress_notZeroGovernor() external {
        vm.expectRevert(IPowerTokenDeployer.NotZeroGovernor.selector);
        _powerTokenDeployer.deploy(address(_bootstrapToken), makeAddr("standardGovernor"), makeAddr("cashToken"));
    }

    function test_deployAddress() external {
        address nextDeploy_ = _powerTokenDeployer.nextDeploy();

        vm.prank(_zeroGovernor);
        address deployed_ = _powerTokenDeployer.deploy(
            address(_bootstrapToken),
            makeAddr("standardGovernor"),
            makeAddr("cashToken")
        );

        assertEq(deployed_, nextDeploy_);
    }
}
