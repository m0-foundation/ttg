// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IBatchGovernor } from "../src/abstract/interfaces/IBatchGovernor.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";

import { ZeroGovernor } from "../src/ZeroGovernor.sol";

import { MockBootstrapToken, MockEmergencyGovernor, MockEmergencyGovernorDeployer } from "./utils/Mocks.sol";
import { MockPowerTokenDeployer, MockStandardGovernor, MockStandardGovernorDeployer } from "./utils/Mocks.sol";
import { TestUtils } from "./utils/TestUtils.sol";

contract ZeroGovernorTests is TestUtils {
    event ResetExecuted(
        address indexed bootstrapToken,
        address standardGovernor,
        address emergencyGovernor,
        address powerToken
    );

    address internal _cashToken1 = makeAddr("cashToken1");
    address internal _cashToken2 = makeAddr("cashToken2");

    uint16 internal _zeroProposalThresholdRatio;

    address[] internal _allowedCashTokens = [_cashToken1, _cashToken2];

    ZeroGovernor internal _zeroGovernor;
    MockBootstrapToken internal _bootstrapToken;
    MockBootstrapToken internal _zeroToken;
    MockBootstrapToken internal _powerToken;
    MockEmergencyGovernor internal _emergencyGovernor;
    MockEmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockStandardGovernor internal _standardGovernor;
    MockStandardGovernorDeployer internal _standardGovernorDeployer;

    function setUp() external {
        _bootstrapToken = new MockBootstrapToken();
        _zeroToken = new MockBootstrapToken();
        _powerToken = new MockBootstrapToken();
        _emergencyGovernor = new MockEmergencyGovernor();
        _emergencyGovernorDeployer = new MockEmergencyGovernorDeployer();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _standardGovernor = new MockStandardGovernor();
        _standardGovernorDeployer = new MockStandardGovernorDeployer();

        _bootstrapToken.setTotalSupply(1);
        _zeroToken.setTotalSupply(1);
        _powerToken.setTotalSupply(1);

        _emergencyGovernor.setThresholdRatio(1);
        _emergencyGovernorDeployer.setNextDeploy(address(_emergencyGovernor));

        _powerTokenDeployer.setNextDeploy(address(_powerToken));

        _standardGovernor.setVoteToken(address(_powerToken));
        _standardGovernor.setCashToken(_cashToken1);
        _standardGovernor.setProposalFee(1);

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

        _standardGovernorDeployer.setLastDeploy(address(_standardGovernor));

        _emergencyGovernorDeployer.setLastDeploy(address(_emergencyGovernor));
    }

    function test_initialState() external {
        assertEq(_zeroGovernor.voteToken(), address(_zeroToken));
        assertEq(_zeroGovernor.emergencyGovernorDeployer(), address(_emergencyGovernorDeployer));
        assertEq(_zeroGovernor.powerTokenDeployer(), address(_powerTokenDeployer));
        assertEq(_zeroGovernor.standardGovernorDeployer(), address(_standardGovernorDeployer));
        assertEq(_zeroGovernor.thresholdRatio(), _zeroProposalThresholdRatio);
        assertEq(_zeroGovernor.isAllowedCashToken(_cashToken1), true);
        assertEq(_zeroGovernor.isAllowedCashToken(_cashToken2), true);
    }

    function test_constructor_invalidEmergencyGovernorDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidEmergencyGovernorDeployerAddress.selector);
        new ZeroGovernor(
            address(_zeroToken),
            address(0),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            _allowedCashTokens
        );
    }

    function test_constructor_invalidPowerTokenDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidPowerTokenDeployerAddress.selector);
        new ZeroGovernor(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(0),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            _allowedCashTokens
        );
    }

    function test_constructor_invalidStandardGovernorDeployerAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidStandardGovernorDeployerAddress.selector);
        new ZeroGovernor(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(0),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            _allowedCashTokens
        );
    }

    function test_constructor_noAllowedCashTokens() external {
        vm.expectRevert(IZeroGovernor.NoAllowedCashTokens.selector);
        new ZeroGovernor(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            new address[](0)
        );
    }

    function test_constructor_invalidCashTokenAddress() external {
        vm.expectRevert(IZeroGovernor.InvalidCashTokenAddress.selector);
        new ZeroGovernor(
            address(_zeroToken),
            address(_emergencyGovernorDeployer),
            address(_powerTokenDeployer),
            address(_standardGovernorDeployer),
            address(_bootstrapToken),
            1,
            1,
            _zeroProposalThresholdRatio,
            new address[](1)
        );
    }

    function test_getProposal_ProposalDoesNotExist() external {
        vm.expectRevert(IBatchGovernor.ProposalDoesNotExist.selector);
        _zeroGovernor.getProposal(0);
    }

    function test_resetToPowerHolders_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.resetToPowerHolders();
    }

    function test_resetToZeroHolders_notZeroGovernor() external {
        vm.expectRevert(IBatchGovernor.NotSelf.selector);
        _zeroGovernor.resetToZeroHolders();
    }
}
