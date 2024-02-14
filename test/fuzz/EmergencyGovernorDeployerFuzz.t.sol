// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IEmergencyGovernorDeployer } from "../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { EmergencyGovernorDeployer } from "../../src/EmergencyGovernorDeployer.sol";

import { IThresholdGovernor } from "src/abstract/interfaces/IThresholdGovernor.sol";

contract EmergencyGovernorDeployerTests is Test {
    address internal _registrar = makeAddr("registrar");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    EmergencyGovernorDeployer internal _deployer;

    function setUp() external {
        _deployer = new EmergencyGovernorDeployer(_zeroGovernor, _registrar);
    }

    function testFuzz_deployAddress(uint16 thresholdRatio_) external {
        uint16 _MIN_THRESHOLD_RATIO = 271;
        uint256 ONE = 10_000;
        address nextDeploy_ = _deployer.nextDeploy();

        vm.prank(_zeroGovernor);
        if (thresholdRatio_ < _MIN_THRESHOLD_RATIO || thresholdRatio_ > ONE) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IThresholdGovernor.InvalidThresholdRatio.selector,
                    thresholdRatio_,
                    _MIN_THRESHOLD_RATIO,
                    ONE
                )
            );
            _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), thresholdRatio_);
        } else {
            address deployed_ = _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), thresholdRatio_);
            assertEq(deployed_, nextDeploy_);
        }
    }
}
