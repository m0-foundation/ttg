// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IDistributionVault } from "../src/interfaces/IDistributionVault.sol";
import { IEmergencyGovernor } from "../src/interfaces/IEmergencyGovernor.sol";
import { IEmergencyGovernorDeployer } from "../src/interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerToken } from "../src/interfaces/IPowerToken.sol";
import { IPowerTokenDeployer } from "../src/interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IStandardGovernorDeployer } from "../src/interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../src/interfaces/IZeroToken.sol";

import { DeployBase } from "../script/DeployBase.sol";

contract Deploy is Test, DeployBase {
    address internal constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint256 internal constant _STANDARD_PROPOSAL_FEE = 0.1 ether;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _david = makeAddr("david");

    address[][2] internal _initialAccounts = [[_alice, _bob], [_carol, _david]];

    uint256[][2] internal _initialBalances = [[uint256(10_000), 20_000], [uint256(1_000_000_000), 2_000_000_000]];

    address[] internal _allowedCashTokens = [_WETH];

    function test_deploy() external {
        address registrar_ = deploy(
            address(this),
            1,
            _initialAccounts,
            _initialBalances,
            _STANDARD_PROPOSAL_FEE,
            _allowedCashTokens
        );

        address emergencyGovernorDeployer_ = getExpectedEmergencyGovernorDeployer(address(this), 1);
        address emergencyGovernor_ = getExpectedEmergencyGovernor(address(this), 1);
        address powerTokenDeployer_ = getExpectedPowerTokenDeployer(address(this), 1);
        address powerToken_ = getExpectedPowerToken(address(this), 1);
        address standardGovernorDeployer_ = getExpectedStandardGovernorDeployer(address(this), 1);
        address standardGovernor_ = getExpectedStandardGovernor(address(this), 1);
        address vault_ = getExpectedVault(address(this), 1);
        address zeroGovernor_ = getExpectedZeroGovernor(address(this), 1);
        address zeroToken_ = getExpectedZeroToken(address(this), 1);

        // Registrar assertions
        assertEq(registrar_, getExpectedRegistrar(address(this), 1));
        assertEq(IRegistrar(registrar_).emergencyGovernorDeployer(), emergencyGovernorDeployer_);
        assertEq(IRegistrar(registrar_).emergencyGovernor(), emergencyGovernor_);
        assertEq(IRegistrar(registrar_).powerTokenDeployer(), powerTokenDeployer_);
        assertEq(IRegistrar(registrar_).powerToken(), powerToken_);
        assertEq(IRegistrar(registrar_).standardGovernorDeployer(), standardGovernorDeployer_);
        assertEq(IRegistrar(registrar_).standardGovernor(), standardGovernor_);
        assertEq(IRegistrar(registrar_).vault(), vault_);
        assertEq(IRegistrar(registrar_).zeroGovernor(), zeroGovernor_);
        assertEq(IRegistrar(registrar_).zeroToken(), zeroToken_);

        // Vault assertions
        assertEq(IDistributionVault(vault_).zeroToken(), zeroToken_);

        // Emergency Governor assertions
        assertEq(IEmergencyGovernor(emergencyGovernor_).registrar(), registrar_);
        assertEq(IEmergencyGovernor(emergencyGovernor_).standardGovernor(), standardGovernor_);
        assertEq(IEmergencyGovernor(emergencyGovernor_).zeroGovernor(), zeroGovernor_);

        // Emergency Governor Deployer assertions
        assertEq(IEmergencyGovernorDeployer(emergencyGovernorDeployer_).registrar(), registrar_);
        assertEq(IEmergencyGovernorDeployer(emergencyGovernorDeployer_).zeroGovernor(), zeroGovernor_);
        assertEq(IEmergencyGovernorDeployer(emergencyGovernorDeployer_).lastDeploy(), emergencyGovernor_);

        // Power Token assertions
        assertEq(IPowerToken(powerToken_).bootstrapToken(), getExpectedBootstrapToken(address(this), 1));
        assertEq(IPowerToken(powerToken_).standardGovernor(), standardGovernor_);
        assertEq(IPowerToken(powerToken_).vault(), vault_);

        // Power Token Deployer assertions
        assertEq(IPowerTokenDeployer(powerTokenDeployer_).vault(), vault_);
        assertEq(IPowerTokenDeployer(powerTokenDeployer_).zeroGovernor(), zeroGovernor_);
        assertEq(IPowerTokenDeployer(powerTokenDeployer_).lastDeploy(), powerToken_);

        // Standard Governor assertions
        assertEq(IStandardGovernor(standardGovernor_).emergencyGovernor(), emergencyGovernor_);
        assertEq(IStandardGovernor(standardGovernor_).registrar(), registrar_);
        assertEq(IStandardGovernor(standardGovernor_).vault(), vault_);
        assertEq(IStandardGovernor(standardGovernor_).zeroGovernor(), zeroGovernor_);
        assertEq(IStandardGovernor(standardGovernor_).zeroToken(), zeroToken_);
        assertEq(IStandardGovernor(standardGovernor_).cashToken(), _allowedCashTokens[0]);

        // Standard Governor Deployer assertions
        assertEq(IStandardGovernorDeployer(standardGovernorDeployer_).registrar(), registrar_);
        assertEq(IStandardGovernorDeployer(standardGovernorDeployer_).vault(), vault_);
        assertEq(IStandardGovernorDeployer(standardGovernorDeployer_).zeroGovernor(), zeroGovernor_);
        assertEq(IStandardGovernorDeployer(standardGovernorDeployer_).zeroToken(), zeroToken_);
        assertEq(IStandardGovernorDeployer(standardGovernorDeployer_).lastDeploy(), standardGovernor_);

        // Zero Governor assertions
        assertEq(IZeroGovernor(zeroGovernor_).emergencyGovernorDeployer(), emergencyGovernorDeployer_);
        assertEq(IZeroGovernor(zeroGovernor_).powerTokenDeployer(), powerTokenDeployer_);
        assertEq(IZeroGovernor(zeroGovernor_).standardGovernorDeployer(), standardGovernorDeployer_);
        assertTrue(IZeroGovernor(zeroGovernor_).isAllowedCashToken(_allowedCashTokens[0]));

        // Zero Token assertions
        assertEq(IZeroToken(zeroToken_).standardGovernorDeployer(), standardGovernorDeployer_);
    }
}
