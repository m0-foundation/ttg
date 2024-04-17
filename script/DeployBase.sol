// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { DistributionVault } from "../src/DistributionVault.sol";
import { EmergencyGovernorDeployer } from "../src/EmergencyGovernorDeployer.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { StandardGovernorDeployer } from "../src/StandardGovernorDeployer.sol";
import { ZeroGovernor } from "../src/ZeroGovernor.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract DeployBase {
    uint16 internal constant _EMERGENCY_PROPOSAL_THRESHOLD_RATIO = 8_000; // 80%
    uint16 internal constant _ZERO_PROPOSAL_THRESHOLD_RATIO = 6_000; // 60%

    /**
     * @dev    Deploys TTG.
     * @param  deployer_            The address of the account deploying the contracts.
     * @param  deployerNonce_       The current nonce of the deployer.
     * @param  initialAccounts_     An array of [Power token holders, Zero token holders].
     * @param  initialBalances_     An array of [Power token balances, Zero token balances].
     * @param  standardProposalFee_ The starting proposal fee for the Standard Governor.
     * @param  allowedCashTokens_   An array of tokens that can be used as cash tokens.
     * @return registrar_           The address of the deployed Registrar.
     */
    function deploy(
        address deployer_,
        uint256 deployerNonce_,
        address[][2] memory initialAccounts_,
        uint256[][2] memory initialBalances_,
        uint256 standardProposalFee_,
        address[] memory allowedCashTokens_
    ) public virtual returns (address registrar_) {
        address emergencyGovernorDeployer_ = _deployEmergencyGovernorDeployer(deployer_, deployerNonce_);
        address powerTokenDeployer_ = _deployPowerTokenDeployer(deployer_, deployerNonce_);
        address standardGovernorDeployer_ = _deployStandardGovernorDeployer(deployer_, deployerNonce_);
        address bootstrapToken_ = _deployBootstrapToken(initialAccounts_[0], initialBalances_[0]);

        address zeroGovernor_ = _deployZeroGovernor(
            deployer_,
            deployerNonce_,
            emergencyGovernorDeployer_,
            powerTokenDeployer_,
            standardGovernorDeployer_,
            bootstrapToken_,
            standardProposalFee_,
            allowedCashTokens_
        );

        _deployZeroToken(deployer_, deployerNonce_, initialAccounts_[1], initialBalances_[1]);
        _deployVault(deployer_, deployerNonce_);

        registrar_ = _deployRegistrar(zeroGovernor_);
    }

    function _deployEmergencyGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) internal returns (address emergencyGovernorDeployer_) {
        emergencyGovernorDeployer_ = address(
            new EmergencyGovernorDeployer(
                _getExpectedZeroGovernor(deployer_, deployerNonce_),
                _getExpectedRegistrar(deployer_, deployerNonce_)
            )
        );
    }

    function _deployPowerTokenDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) internal returns (address powerTokenDeployer_) {
        powerTokenDeployer_ = address(
            new PowerTokenDeployer(
                _getExpectedZeroGovernor(deployer_, deployerNonce_),
                _getExpectedVault(deployer_, deployerNonce_)
            )
        );
    }

    function _deployStandardGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) internal returns (address standardGovernorDeployer_) {
        standardGovernorDeployer_ = address(
            new StandardGovernorDeployer(
                _getExpectedZeroGovernor(deployer_, deployerNonce_),
                _getExpectedRegistrar(deployer_, deployerNonce_),
                _getExpectedVault(deployer_, deployerNonce_),
                _getExpectedZeroToken(deployer_, deployerNonce_)
            )
        );
    }

    function _deployBootstrapToken(
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_
    ) internal returns (address bootstrapToken_) {
        bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));
    }

    function _deployZeroGovernor(
        address deployer_,
        uint256 deployerNonce_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        address[] memory allowedCashTokens_
    ) internal returns (address zeroGovernor_) {
        zeroGovernor_ = address(
            new ZeroGovernor(
                _getExpectedZeroToken(deployer_, deployerNonce_),
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
    }

    function _deployZeroToken(
        address deployer_,
        uint256 deployerNonce_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_
    ) internal returns (address zeroToken_) {
        zeroToken_ = address(
            new ZeroToken(
                _getExpectedStandardGovernorDeployer(deployer_, deployerNonce_),
                initialZeroAccounts_,
                initialZeroBalances_
            )
        );
    }

    function _deployVault(address deployer_, uint256 deployerNonce_) internal returns (address vault_) {
        vault_ = address(new DistributionVault(_getExpectedZeroToken(deployer_, deployerNonce_)));
    }

    function _deployRegistrar(address zeroGovernor_) internal returns (address registrar_) {
        registrar_ = address(new Registrar(zeroGovernor_));
    }

    function _getExpectedEmergencyGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_);
    }

    function getExpectedEmergencyGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedEmergencyGovernorDeployer(deployer_, deployerNonce_);
    }

    function _getExpectedEmergencyGovernor(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(_getExpectedEmergencyGovernorDeployer(deployer_, deployerNonce_), 1);
    }

    function getExpectedEmergencyGovernor(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedEmergencyGovernor(deployer_, deployerNonce_);
    }

    function _getExpectedPowerTokenDeployer(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 1);
    }

    function getExpectedPowerTokenDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedPowerTokenDeployer(deployer_, deployerNonce_);
    }

    function _getExpectedPowerToken(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(_getExpectedPowerTokenDeployer(deployer_, deployerNonce_), 1);
    }

    function getExpectedPowerToken(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedPowerToken(deployer_, deployerNonce_);
    }

    function _getExpectedStandardGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 2);
    }

    function getExpectedStandardGovernorDeployer(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedStandardGovernorDeployer(deployer_, deployerNonce_);
    }

    function _getExpectedStandardGovernor(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(_getExpectedStandardGovernorDeployer(deployer_, deployerNonce_), 1);
    }

    function getExpectedStandardGovernor(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedStandardGovernor(deployer_, deployerNonce_);
    }

    function _getExpectedBootstrapToken(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 3);
    }

    function getExpectedBootstrapToken(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedBootstrapToken(deployer_, deployerNonce_);
    }

    function _getExpectedZeroGovernor(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 4);
    }

    function getExpectedZeroGovernor(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedZeroGovernor(deployer_, deployerNonce_);
    }

    function _getExpectedZeroToken(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 5);
    }

    function getExpectedZeroToken(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedZeroToken(deployer_, deployerNonce_);
    }

    function _getExpectedVault(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 6);
    }

    function getExpectedVault(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedVault(deployer_, deployerNonce_);
    }

    function _getExpectedRegistrar(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 7);
    }

    function getExpectedRegistrar(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedRegistrar(deployer_, deployerNonce_);
    }

    function getDeployerNonceAfterTTGDeployment(uint256 deployerNonce_) public pure virtual returns (uint256) {
        return deployerNonce_ + 8;
    }
}
