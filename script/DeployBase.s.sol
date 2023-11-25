// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { IEmergencyGovernor } from "../src/interfaces/IEmergencyGovernor.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";
import { IStandardGovernor } from "../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../src/interfaces/IZeroGovernor.sol";

import { ContractHelper } from "../src/libs/ContractHelper.sol";

import { DistributionVault } from "../src/DistributionVault.sol";
import { EmergencyGovernorDeployer } from "../src/EmergencyGovernorDeployer.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { StandardGovernorDeployer } from "../src/StandardGovernorDeployer.sol";
import { ZeroGovernor } from "../src/ZeroGovernor.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract DeployBase is Script {
    function deploy(
        address deployer_,
        uint256 deployerNonce_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_,
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_,
        address[] memory allowedCashTokens_,
        uint256 standardProposalFee_,
        uint16 emergencyProposalThresholdRatio_,
        uint16 zeroProposalThresholdRatio_
    ) public returns (address registrar_) {
        console2.log("deployer: ", deployer_);

        // ZeroToken needs registrar address.
        // DistributionVault needs zeroToken address.
        // ZeroGovernor needs registrar, zeroToken, and allowedCashTokens.
        // EmergencyGovernorDeployer needs registrar and zeroGovernor address.
        // StandardGovernorDeployer needs registrar, vault, zeroGovernor, and zeroToken address.
        // PowerTokenDeployer needs registrar and vault.
        // PowerBootstrapToken needs nothing.
        // Registrar needs standardGovernorDeployer, emergencyGovernorDeployer, powerTokenDeployer, and bootstrapToken address.

        address expectedRegistrar_ = ContractHelper.getContractFrom(deployer_, deployerNonce_ + 7);

        vm.startBroadcast(deployer_);

        address zeroToken_ = address(new ZeroToken(expectedRegistrar_, initialZeroAccounts_, initialZeroBalances_));

        address vault_ = address(new DistributionVault(zeroToken_));

        address zeroGovernor_ = address(
            new ZeroGovernor(expectedRegistrar_, zeroToken_, allowedCashTokens_, zeroProposalThresholdRatio_)
        );

        address emergencyGovernorDeployer_ = address(new EmergencyGovernorDeployer(expectedRegistrar_, zeroGovernor_));

        address standardGovernorDeployer_ = address(
            new StandardGovernorDeployer(expectedRegistrar_, vault_, zeroGovernor_, zeroToken_)
        );

        address powerTokenDeployer_ = address(new PowerTokenDeployer(expectedRegistrar_, vault_));

        address bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));

        registrar_ = address(
            new Registrar(
                standardGovernorDeployer_,
                emergencyGovernorDeployer_,
                powerTokenDeployer_,
                bootstrapToken_,
                standardProposalFee_,
                emergencyProposalThresholdRatio_
            )
        );

        vm.stopBroadcast();

        console2.log("Registrar address:", registrar_);
        console2.log("Power Token Address:", IRegistrar(registrar_).powerToken());
        console2.log("Zero Token Address:", zeroToken_);
        console2.log("Distribution Vault Address:", vault_);
        console2.log("Zero Governor Address:", zeroGovernor_);
        console2.log("Emergency Governor Address:", IRegistrar(registrar_).emergencyGovernor());
        console2.log("Standard Governor Address:", IRegistrar(registrar_).standardGovernor());
    }
}
