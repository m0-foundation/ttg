// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IEmergencyGovernorDeployer } from "../../src/interfaces/IEmergencyGovernorDeployer.sol";

import { EmergencyGovernorDeployer } from "../../src/EmergencyGovernorDeployer.sol";

import { IThresholdGovernor } from "../../src/abstract/interfaces/IThresholdGovernor.sol";

contract EmergencyGovernorDeployerTests is Test {
    address internal _registrar = makeAddr("registrar");
    address internal _zeroGovernor = makeAddr("zeroGovernor");

    EmergencyGovernorDeployer internal _deployer;

    function setUp() external {
        _deployer = new EmergencyGovernorDeployer(_zeroGovernor, _registrar);
    }

    function testFuzz_deployAddress(uint256 quorumNumerator_) external {
        uint256 minQuorumNumerator = 271;
        uint256 quorumDenominator = 10_000;
        address nextDeploy_ = _deployer.nextDeploy();

        vm.prank(_zeroGovernor);
        if (quorumNumerator_ < minQuorumNumerator || quorumNumerator_ > quorumDenominator) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IThresholdGovernor.InvalidQuorumNumerator.selector,
                    quorumNumerator_,
                    minQuorumNumerator,
                    quorumDenominator
                )
            );
            _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), quorumNumerator_);
        } else {
            address deployed_ = _deployer.deploy(makeAddr("voteToken"), makeAddr("standardGovernor"), quorumNumerator_);
            assertEq(deployed_, nextDeploy_);
        }
    }
}
