// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";
import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { DistributionVault } from "../src/DistributionVault.sol";
import { EmergencyGovernorDeployer } from "../src/EmergencyGovernorDeployer.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { StandardGovernorDeployer } from "../src/StandardGovernorDeployer.sol";
import { ZeroGovernor } from "../src/ZeroGovernor.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract DeployBase is Script {
    error DeployerNonceMismatch(uint256 expectedDeployerNonce, uint256 actualDeployerNonce);

    uint16 internal constant _EMERGENCY_PROPOSAL_THRESHOLD_RATIO = 8_000; // 80%
    uint16 internal constant _ZERO_PROPOSAL_THRESHOLD_RATIO = 6_000; // 60%

    // NOTE: Ensure this is the current nonce (transaction count) of the deploying address.
    uint256 internal constant _DEPLOYER_NONCE = 0;

    function deploy(
        address deployer_,
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_,
        uint256 standardProposalFee_,
        address[] memory allowedCashTokens_
    ) public returns (address registrar_) {
        console2.log("deployer:", deployer_);

        if (_DEPLOYER_NONCE != vm.getNonce(deployer_)) {
            revert DeployerNonceMismatch(_DEPLOYER_NONCE, vm.getNonce(deployer_));
        }

        address emergencyGovernorDeployer_ = _deployEmergencyGovernorDeployer(
            deployer_,
            _DEPLOYER_NONCE + 4, // ZeroGovernor deployment nonce
            _DEPLOYER_NONCE + 7 // Registrar deployment nonce
        );

        address powerTokenDeployer_ = _deployPowerTokenDeployer(
            deployer_,
            _DEPLOYER_NONCE + 4, // ZeroGovernor deployment nonce
            _DEPLOYER_NONCE + 6 // DistributionVault deployment nonce
        );

        address standardGovernorDeployer_ = _deployStandardGovernorDeployer(
            deployer_,
            _DEPLOYER_NONCE + 4, // ZeroGovernor deployment nonce
            _DEPLOYER_NONCE + 7, // Registrar deployment nonce
            _DEPLOYER_NONCE + 6, // DistributionVault deployment nonce
            _DEPLOYER_NONCE + 5 // ZeroToken deployment nonce
        );

        address bootstrapToken_ = _deployBootstrapToken(deployer_, initialPowerAccounts_, initialPowerBalances_);

        address zeroGovernor_ = _deployZeroGovernor(
            deployer_,
            _DEPLOYER_NONCE + 5, // ZeroToken deployment nonce
            emergencyGovernorDeployer_,
            powerTokenDeployer_,
            standardGovernorDeployer_,
            bootstrapToken_,
            standardProposalFee_,
            allowedCashTokens_
        );

        address zeroToken_ = _deployZeroToken(
            deployer_,
            _DEPLOYER_NONCE + 2, // StandardGovernorDeployer deployment nonce
            initialZeroAccounts_,
            initialZeroBalances_
        );

        address vault_ = _deployVault(
            deployer_,
            _DEPLOYER_NONCE + 5 // ZeroToken deployment nonce
        );

        registrar_ = _deployRegistrar(deployer_, zeroGovernor_);

        console2.log("Registrar Address:", registrar_);
        console2.log("Power Token Address:", IRegistrar(registrar_).powerToken());
        console2.log("Zero Token Address:", zeroToken_);
        console2.log("Standard Governor Address:", IRegistrar(registrar_).standardGovernor());
        console2.log("Emergency Governor Address:", IRegistrar(registrar_).emergencyGovernor());
        console2.log("Zero Governor Address:", zeroGovernor_);
        console2.log("Distribution Vault Address:", vault_);
    }

    function _deployEmergencyGovernorDeployer(
        address deployer_,
        uint256 zeroGovernorDeploymentNonce_,
        uint256 registrarDeploymentNonce_
    ) internal returns (address emergencyGovernorDeployer_) {
        vm.startBroadcast(deployer_);
        emergencyGovernorDeployer_ = address(
            new EmergencyGovernorDeployer(
                ContractHelper.getContractFrom(deployer_, zeroGovernorDeploymentNonce_),
                ContractHelper.getContractFrom(deployer_, registrarDeploymentNonce_)
            )
        );
        vm.stopBroadcast();
    }

    function _deployPowerTokenDeployer(
        address deployer_,
        uint256 zeroGovernorDeploymentNonce_,
        uint256 vaultDeploymentNonce_
    ) internal returns (address powerTokenDeployer_) {
        vm.startBroadcast(deployer_);
        powerTokenDeployer_ = address(
            new PowerTokenDeployer(
                ContractHelper.getContractFrom(deployer_, zeroGovernorDeploymentNonce_),
                ContractHelper.getContractFrom(deployer_, vaultDeploymentNonce_)
            )
        );
        vm.stopBroadcast();
    }

    function _deployStandardGovernorDeployer(
        address deployer_,
        uint256 zeroGovernorDeploymentNonce_,
        uint256 registrarDeploymentNonce_,
        uint256 vaultDeploymentNonce_,
        uint256 zeroTokenDeploymentNonce_
    ) internal returns (address standardGovernorDeployer_) {
        vm.startBroadcast(deployer_);
        standardGovernorDeployer_ = address(
            new StandardGovernorDeployer(
                ContractHelper.getContractFrom(deployer_, zeroGovernorDeploymentNonce_),
                ContractHelper.getContractFrom(deployer_, registrarDeploymentNonce_),
                ContractHelper.getContractFrom(deployer_, vaultDeploymentNonce_),
                ContractHelper.getContractFrom(deployer_, zeroTokenDeploymentNonce_)
            )
        );
        vm.stopBroadcast();
    }

    function _deployBootstrapToken(
        address deployer_,
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_
    ) internal returns (address bootstrapToken_) {
        vm.startBroadcast(deployer_);
        bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));
        vm.stopBroadcast();
    }

    function _deployZeroGovernor(
        address deployer_,
        uint256 zeroTokenDeploymentNonce_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        address[] memory allowedCashTokens_
    ) internal returns (address zeroGovernor_) {
        vm.startBroadcast(deployer_);
        zeroGovernor_ = address(
            new ZeroGovernor(
                ContractHelper.getContractFrom(deployer_, zeroTokenDeploymentNonce_),
                emergencyGovernorDeployer_,
                powerTokenDeployer_,
                standardGovernorDeployer_,
                bootstrapToken_,
                standardProposalFee_,
                _EMERGENCY_PROPOSAL_THRESHOLD_RATIO,
                _ZERO_PROPOSAL_THRESHOLD_RATIO,
                allowedCashTokens_
            )
        );
        vm.stopBroadcast();
    }

    function _deployZeroToken(
        address deployer_,
        uint256 standardGovernorDeployerDeploymentNonce_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_
    ) internal returns (address zeroToken_) {
        vm.startBroadcast(deployer_);
        zeroToken_ = address(
            new ZeroToken(
                ContractHelper.getContractFrom(deployer_, standardGovernorDeployerDeploymentNonce_),
                initialZeroAccounts_,
                initialZeroBalances_
            )
        );
        vm.stopBroadcast();
    }

    function _deployVault(address deployer_, uint256 zeroTokenDeploymentNonce_) internal returns (address vault_) {
        vm.startBroadcast(deployer_);
        vault_ = address(new DistributionVault(ContractHelper.getContractFrom(deployer_, zeroTokenDeploymentNonce_)));
        vm.stopBroadcast();
    }

    function _deployRegistrar(address deployer_, address zeroGovernor_) internal returns (address registrar_) {
        vm.startBroadcast(deployer_);
        registrar_ = address(new Registrar(zeroGovernor_));
        vm.stopBroadcast();
    }
}
