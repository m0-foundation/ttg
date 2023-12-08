// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DeployBase } from "../../script/DeployBase.s.sol";

import { IGovernor } from "../../src/abstract/interfaces/IGovernor.sol";
import { IRegistrar } from "../../src/interfaces/IRegistrar.sol";
import { IZeroGovernor } from "../../src/interfaces/IZeroGovernor.sol";
import { IZeroToken } from "../../src/interfaces/IZeroToken.sol";

import { ERC20PermitHarness } from "../utils/ERC20PermitHarness.sol";
import { TestUtils } from "../utils/TestUtils.sol";

/// @notice Common setup for integration tests
abstract contract IntegrationBaseSetup is TestUtils {
    address internal _deployer = makeAddr("deployer");

    IRegistrar internal _registrar;
    IZeroGovernor _zeroGovernor;
    IZeroToken _zeroToken;

    ERC20PermitHarness internal _cashToken1 = new ERC20PermitHarness("Cash Token 1", "CASH1", 18);
    ERC20PermitHarness internal _cashToken2 = new ERC20PermitHarness("Cash Token 1", "CASH2", 6);

    address[] internal _allowedCashTokens = [address(_cashToken1), address(_cashToken2)];

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eve = makeAddr("eve");
    address internal _frank = makeAddr("frank");

    address[] internal _initialPowerAccounts = [_alice, _bob, _carol];

    uint256[] internal _initialPowerBalances = [55, 25, 20];

    address[] internal _initialZeroAccounts = [_dave, _eve, _frank];

    uint256 _daveWeight = 60_000_000e6;
    uint256 _eveWeight = 30_000_000e6;
    uint256 _frankWeight = 10_000_000e6;

    uint256[] internal _initialZeroBalances = [_daveWeight, _eveWeight, _frankWeight];

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
        _zeroGovernor = IZeroGovernor(_registrar.zeroGovernor());
        _zeroToken = IZeroToken(_registrar.zeroToken());
    }
}
