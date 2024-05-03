// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { EmergencyGovernorDeployer } from "../../src/EmergencyGovernorDeployer.sol";

import { IThresholdGovernor } from "../../src/abstract/interfaces/IThresholdGovernor.sol";

contract EmergencyGovernorDeployerTests is Test {
    address internal _registrar = makeAddr("registrar");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    EmergencyGovernorDeployer internal _deployer;

    function setUp() external {
        _deployer = new EmergencyGovernorDeployer(_zeroGovernor, _registrar);
    }

    function testFuzz_deployAddress(uint16 thresholdRatio_) external {
        uint16 minThresholdRatio = 271;
        uint256 one = 10_000;
        address nextDeploy_ = _deployer.nextDeploy();

        vm.prank(_zeroGovernor);
        if (thresholdRatio_ < minThresholdRatio || thresholdRatio_ > one) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IThresholdGovernor.InvalidThresholdRatio.selector,
                    thresholdRatio_,
                    minThresholdRatio,
                    one
                )
            );
            _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), thresholdRatio_);
        } else {
            address deployed_ = _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), thresholdRatio_);
            assertEq(deployed_, nextDeploy_);
        }
    }
}
