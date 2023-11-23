// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

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
        address[] memory allowedCashTokens_
    ) public returns (address registrar_) {
        console2.log("deployer: ", deployer_);

        // ZeroToken needs registrar address.
        // DistributionVault needs zeroToken address.
        // DualGovernorDeployer needs registrar, vault, and zeroToken address.
        // PowerTokenDeployer needs registrar and vault.
        // PowerBootstrapToken needs nothing.
        // Registrar needs governorDeployer, powerTokenDeployer, bootstrapToken, and cashToken address.

        address expectedRegistrar_ = ContractHelper.getContractFrom(deployer_, deployerNonce_ + 5);

        vm.startBroadcast(deployer_);

        address zeroToken_ = address(new ZeroToken(expectedRegistrar_, initialZeroAccounts_, initialZeroBalances_));

        address vault_ = address(new DistributionVault(zeroToken_));

        address governorDeployer_ = address(
            new DualGovernorDeployer(expectedRegistrar_, vault_, zeroToken_, allowedCashTokens_)
        );

        address powerTokenDeployer_ = address(new PowerTokenDeployer(expectedRegistrar_, vault_));

        address bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));

        registrar_ = address(new Registrar(governorDeployer_, powerTokenDeployer_, bootstrapToken_));

        vm.stopBroadcast();

        address governor_ = IRegistrar(registrar_).governor();

        console2.log("Zero Token Address:", zeroToken_);
        console2.log("Distribution Vault Address:", vault_);
        console2.log("Registrar address:", registrar_);
        console2.log("DualGovernor Address:", governor_);
        console2.log("Power Token Address:", IDualGovernor(governor_).powerToken());
    }
}
