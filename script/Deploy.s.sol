// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";

import { ContractHelper } from "../src/ContractHelper.sol";
import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract Deploy is Script {
    uint256 internal _DEPLOYER_STARTING_NONCE = 0;

    address internal _weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address internal _deployer;
    address internal _registrar;

    address[] internal _initialZeroAccounts;
    uint256[] internal _initialZeroBalances;

    address[] internal _initialPowerAccounts;
    uint256[] internal _initialPowerBalances;

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC");

        (_deployer, ) = deriveRememberKey(mnemonic, 0);

        console.log("deployer: %s", _deployer);
    }

    function run() public {
        vm.startBroadcast(_deployer);

        // ZeroToken needs registrar address.
        // DualGovernorDeployer needs registrar and zeroToken address.
        // PowerTokenDeployer needs registrar and treasury.
        // Registrar needs governorDeployer, powerTokenDeployer, bootstrapToken, and cashToken address.
        // PowerBootstrapToken needs nothing.

        address expectedRegistrar_ = ContractHelper.getContractFrom(_deployer, _DEPLOYER_STARTING_NONCE + 4);
        address zeroToken_ = address(new ZeroToken(expectedRegistrar_, _initialZeroAccounts, _initialZeroBalances));
        address governorDeployer_ = address(new DualGovernorDeployer(expectedRegistrar_, zeroToken_));
        address powerTokenDeployer_ = address(new PowerTokenDeployer(expectedRegistrar_, _deployer)); // `_treasury`
        address bootstrapToken_ = address(new PowerBootstrapToken(_initialPowerAccounts, _initialPowerBalances));

        Registrar registrar_ = new Registrar(governorDeployer_, powerTokenDeployer_, bootstrapToken_, _weth);

        _registrar = address(registrar_);

        address governor_ = registrar_.governor();

        console.log("Zero Token Address: ", zeroToken_);
        console.log("Registrar address: ", _registrar);
        console.log("DualGovernor Address: ", governor_);
        console.log("Power Token Address: ", IDualGovernor(governor_).powerToken());

        vm.stopBroadcast();
    }
}
