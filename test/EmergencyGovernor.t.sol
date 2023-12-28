// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IEmergencyGovernor } from "../src/interfaces/IEmergencyGovernor.sol";

import { EmergencyGovernor } from "../src/EmergencyGovernor.sol";
import { ZeroGovernor } from "../src/ZeroGovernor.sol";

import {
    MockBootstrapToken,
    MockEmergencyGovernorDeployer,
    MockPowerTokenDeployer,
    MockRegistrar,
    MockStandardGovernor,
    MockStandardGovernorDeployer
} from "./utils/Mocks.sol";

import { EmergencyGovernorHarness } from "./utils/EmergencyGovernorHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract EmergencyGovernorTests is TestUtils {
    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");

    uint16 internal _emergencyProposalThresholdRatio = 9_000; // 90%
    uint16 internal _zeroProposalThresholdRatio = 6_000; // 60%

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    MockBootstrapToken internal _bootstrapToken;
    MockBootstrapToken internal _zeroToken;
    MockBootstrapToken internal _powerToken;
    MockEmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockRegistrar internal _registrar;
    MockStandardGovernor internal _standardGovernor;
    MockStandardGovernorDeployer internal _standardGovernorDeployer;

    EmergencyGovernorHarness internal _emergencyGovernor;
    ZeroGovernor internal _zeroGovernor;

    function setUp() external {
        _bootstrapToken = new MockBootstrapToken();
        _zeroToken = new MockBootstrapToken();
        _powerToken = new MockBootstrapToken();
        _emergencyGovernorDeployer = new MockEmergencyGovernorDeployer();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _registrar = new MockRegistrar();
        _standardGovernor = new MockStandardGovernor();
        _standardGovernorDeployer = new MockStandardGovernorDeployer();

        _bootstrapToken.setTotalSupply(1);
        _zeroToken.setTotalSupply(1);
        _powerToken.setTotalSupply(1);

        _emergencyGovernorDeployer.setNextDeploy(address(_emergencyGovernor));

        _powerTokenDeployer.setNextDeploy(address(_powerToken));

        _standardGovernor.setVoteToken(address(_powerToken));
        _standardGovernor.setCashToken(_cashToken1);
        _standardGovernor.setProposalFee(1e18);

        _standardGovernorDeployer.setNextDeploy(address(_standardGovernor));

        _zeroGovernor = new ZeroGovernor(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            _allowedCashTokens
        );

        _emergencyGovernor = new EmergencyGovernorHarness(
            address(_powerToken),
            address(_zeroGovernor),
            address(_registrar),
            address(_standardGovernor),
            _emergencyProposalThresholdRatio
        );

        _standardGovernorDeployer.setLastDeploy(address(_standardGovernor));

        _emergencyGovernorDeployer.setLastDeploy(address(_emergencyGovernor));
    }

    function test_initialState() external {
        assertEq(_emergencyGovernor.voteToken(), address(_powerToken));
        assertEq(_emergencyGovernor.zeroGovernor(), address(_zeroGovernor));
        assertEq(_emergencyGovernor.registrar(), address(_registrar));
        assertEq(_emergencyGovernor.standardGovernor(), address(_standardGovernor));
        assertEq(_emergencyGovernor.thresholdRatio(), _emergencyProposalThresholdRatio);
    }

    /* ============ constructor ============ */
    function test_constructor_invalidZeroGovernorAddress() external {
        vm.expectRevert(IEmergencyGovernor.InvalidZeroGovernorAddress.selector);
        new EmergencyGovernor(
            address(_powerToken),
            address(0),
            address(_registrar),
            address(_standardGovernor),
            _emergencyProposalThresholdRatio
        );
    }

    function test_constructor_invalidRegistrarAddress() external {
        vm.expectRevert(IEmergencyGovernor.InvalidRegistrarAddress.selector);
        new EmergencyGovernor(
            address(_powerToken),
            address(_zeroGovernor),
            address(0),
            address(_standardGovernor),
            _emergencyProposalThresholdRatio
        );
    }

    function test_constructor_invalidStandardGovernorAddress() external {
        vm.expectRevert(IEmergencyGovernor.InvalidStandardGovernorAddress.selector);
        new EmergencyGovernor(
            address(_powerToken),
            address(_zeroGovernor),
            address(_registrar),
            address(0),
            _emergencyProposalThresholdRatio
        );
    }

    /* ============ setThresholdRatio ============ */
    function test_setThresholdRatio_notZeroGovernor() external {
        vm.expectRevert(IEmergencyGovernor.NotZeroGovernor.selector);
        _emergencyGovernor.setThresholdRatio(_emergencyProposalThresholdRatio);
    }

    /* ============ addToList ============ */
    function test_addToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _emergencyGovernor.addToList(bytes32(0), address(0));
    }

    /* ============ removeFromList ============ */
    function test_removeFromList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _emergencyGovernor.removeFromList(bytes32(0), address(0));
    }

    /* ============ removeFromAndAddToList ============ */
    function test_removeFromAndAddToList_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _emergencyGovernor.removeFromAndAddToList(bytes32(0), address(0), address(0));
    }

    /* ============ setKey ============ */
    function test_setKey_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _emergencyGovernor.setKey(bytes32(0), bytes32(0));
    }

    /* ============ setStandardProposalFee ============ */
    function test_setStandardProposalFee_notSelf() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _emergencyGovernor.setStandardProposalFee(0);
    }

    /* ============ revertIfInvalidCalldata ============ */
    function test_revertIfInvalidCalldata() external {
        vm.expectRevert(IBatchGovernor.InvalidCallData.selector);
        _emergencyGovernor.revertIfInvalidCalldata(abi.encode("randomCalldata"));
    }
}
