// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DeployBase } from "../../script/DeployBase.s.sol";

import { IBatchGovernor } from "../../src/abstract/interfaces/IBatchGovernor.sol";
import { IEmergencyGovernor } from "../../src/interfaces/IEmergencyGovernor.sol";
import { IGovernor } from "../../src/abstract/interfaces/IGovernor.sol";
import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";
import { IRegistrar } from "../../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../../src/interfaces/IStandardGovernor.sol";
import { IThresholdGovernor } from "../../src/abstract/interfaces/IThresholdGovernor.sol";
import { IZeroGovernor } from "../../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";

import { ERC20ExtendedHarness } from "../utils/ERC20ExtendedHarness.sol";
import { TestUtils } from "../utils/TestUtils.sol";

/// @notice Common setup for integration tests
abstract contract IntegrationBaseSetup is TestUtils {
    address internal _deployer = makeAddr("deployer");

    IRegistrar internal _registrar;

    IPowerToken _powerToken;
    IZeroToken _zeroToken;

    IEmergencyGovernor _emergencyGovernor;
    IStandardGovernor _standardGovernor;
    IZeroGovernor _zeroGovernor;

    ERC20ExtendedHarness internal _cashToken1 = new ERC20ExtendedHarness("Cash Token 1", "CASH1", 18);
    ERC20ExtendedHarness internal _cashToken2 = new ERC20ExtendedHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eve = makeAddr("eve");
    address internal _frank = makeAddr("frank");

    address[] internal _initialPowerAccounts = [_alice, _bob, _carol];

    uint256 _aliceInitialPowerBalance = 55;
    uint256 _bobInitialPowerBalance = 25;
    uint256 _carolInitialPowerBalance = 20;

    uint256 _alicePowerWeight = _aliceInitialPowerBalance * 1e7;
    uint256 _bobPowerWeight = _bobInitialPowerBalance * 1e7;
    uint256 _carolPowerWeight = _carolInitialPowerBalance * 1e7;

    uint256[] internal _initialPowerBalances = [
        _aliceInitialPowerBalance,
        _bobInitialPowerBalance,
        _carolInitialPowerBalance
    ];

    address[] internal _initialZeroAccounts = [_dave, _eve, _frank];
    uint256 _initialZeroAccountsLength = _initialZeroAccounts.length;
    uint256 _cashToken1MaxAmount = type(uint256).max / _initialZeroAccountsLength;

    uint256 _daveZeroWeight = 60_000_000e6;
    uint256 _eveZeroWeight = 30_000_000e6;
    uint256 _frankZeroWeight = 10_000_000e6;

    uint256[] internal _initialZeroBalances = [_daveZeroWeight, _eveZeroWeight, _frankZeroWeight];

    uint256 internal _standardProposalFee = 1e18;

    DeployBase internal _deploy;

    function setUp() external {
        _deploy = new DeployBase();

        address registrar_ = _deploy.deploy(
            _deployer,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _standardProposalFee,
            _allowedCashTokens
        );

        _registrar = IRegistrar(registrar_);

        _powerToken = IPowerToken(_registrar.powerToken());
        _zeroToken = IZeroToken(_registrar.zeroToken());

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());

        for (uint256 i; i < _initialZeroAccounts.length; i++) {
            address account_ = _initialZeroAccounts[i];
            _cashToken1.mint(account_, _cashToken1MaxAmount);

            vm.prank(account_);
            _cashToken1.approve(address(_standardGovernor), _cashToken1MaxAmount);
        }
    }
}
