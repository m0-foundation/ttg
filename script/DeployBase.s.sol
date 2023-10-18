// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { ContractHelper } from "../src/ContractHelper.sol";
import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";
import { DistributionVault } from "../src/DistributionVault.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract DeployBase is Script {
    function deploy(
        address deployer_,
        uint256 deployerNonce_,
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_,
        address cashToken_
    ) public returns (address registrar_) {
        vm.startBroadcast(deployer_);

        console.log("deployer: ", deployer_);

        // ZeroToken needs registrar address.
        // DistributionVault needs zeroToken address.
        // DualGovernorDeployer needs registrar, vault, and zeroToken address.
        // PowerTokenDeployer needs registrar and vault.
        // PowerBootstrapToken needs nothing.
        // Registrar needs governorDeployer, powerTokenDeployer, bootstrapToken, and cashToken address.

        address expectedRegistrar_ = ContractHelper.getContractFrom(deployer_, deployerNonce_ + 5);

        address zeroToken_ = address(new ZeroToken(expectedRegistrar_, initialZeroAccounts_, initialZeroBalances_));
        address vault_ = address(new DistributionVault(zeroToken_));
        address governorDeployer_ = address(new DualGovernorDeployer(expectedRegistrar_, vault_, zeroToken_));
        address powerTokenDeployer_ = address(new PowerTokenDeployer(expectedRegistrar_, vault_));
        address bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));

        registrar_ = address(new Registrar(governorDeployer_, powerTokenDeployer_, bootstrapToken_, cashToken_));

        address governor_ = IRegistrar(registrar_).governor();

        console.log("Zero Token Address:", zeroToken_);
        console.log("Distribution Vault Address:", vault_);
        console.log("Registrar address:", registrar_);
        console.log("DualGovernor Address:", governor_);
        console.log("Power Token Address:", IDualGovernor(governor_).powerToken());

        vm.stopBroadcast();
    }
}
