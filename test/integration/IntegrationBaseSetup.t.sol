// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DeployBase } from "../../script/DeployBase.sol";

import { IEmergencyGovernor } from "../../src/interfaces/IEmergencyGovernor.sol";
import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";
import { IDistributionVault } from "../../src/interfaces/IDistributionVault.sol";

import { ERC20ExtendedHarness } from "../utils/ERC20ExtendedHarness.sol";
import { TestUtils } from "../utils/TestUtils.sol";

/// @dev Common setup for integration tests
abstract contract IntegrationBaseSetup is TestUtils {
    IRegistrar internal _registrar;

    IPowerToken internal _powerToken;
    IZeroToken internal _zeroToken;

    IEmergencyGovernor internal _emergencyGovernor;
    IStandardGovernor internal _standardGovernor;
    IZeroGovernor internal _zeroGovernor;

    IDistributionVault internal _vault;

    ERC20ExtendedHarness internal _cashToken1 = new ERC20ExtendedHarness("Cash Token 1", "CASH1", 18);
    ERC20ExtendedHarness internal _cashToken2 = new ERC20ExtendedHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eve = makeAddr("eve");
    address internal _frank = makeAddr("frank");

    address[][2] internal _initialAccounts = [[_alice, _bob, _carol], [_dave, _eve, _frank]];
    uint256[][2] internal _initialBalances = [
        [uint256(55), 25, 20],
        [uint256(60_000_000e6), 30_000_000e6, 10_000_000e6]
    ];

    uint256 internal _initialZeroAccountsLength = _initialAccounts[1].length;
    uint256 internal _cashToken1MaxAmount = type(uint256).max / _initialZeroAccountsLength;

    uint256 internal _standardProposalFee = 1e18;

    DeployBase internal _deploy;

    function setUp() external {
        _deploy = new DeployBase();

        // NOTE: Using `DeployBase` as a contract instead of a script, means that the deployer is `_deploy` itself.
        address registrar_ = _deploy.deploy(
            address(_deploy),
            1,
            _initialAccounts,
            _initialBalances,
            _standardProposalFee,
            _allowedCashTokens
        );

        _registrar = IRegistrar(registrar_);

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());

        _vault = IDistributionVault(_standardGovernor.vault());

        for (uint256 i; i < _initialZeroAccountsLength; i++) {
            address account_ = _initialAccounts[1][i];
            _cashToken1.mint(account_, _cashToken1MaxAmount);

            vm.prank(account_);
            _cashToken1.approve(address(_standardGovernor), _cashToken1MaxAmount);

            vm.prank(account_);
            _cashToken1.approve(address(_powerToken), _cashToken1MaxAmount);
        }
    }
}
