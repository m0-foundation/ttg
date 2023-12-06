// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IDeployer, IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";

/// @title A Deterministic deployer of Power Token contracts using CREATE.
contract PowerTokenDeployer is IPowerTokenDeployer {
    /// @inheritdoc IPowerTokenDeployer
    address public immutable vault;

    /// @inheritdoc IPowerTokenDeployer
    address public immutable zeroGovernor;

    /// @inheritdoc IDeployer
    address public lastDeploy;

    /// @inheritdoc IDeployer
    uint256 public nonce;

    /// @notice Throws if called by any account other than the Zero Governor.
    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
        _;
    }

    /**
     * @notice Constructs a new PowerTokenDeployer contract.
     * @param zeroGovernor_ The address of the ZeroGovernor contract.
     * @param vault_ The address of the Vault contract.
     */
    constructor(address zeroGovernor_, address vault_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    /**
     * @notice Deploys a new PowerToken contract.
     * @param bootstrapToken_ The address of the BootstrapToken contract.
     * @param standardGovernor_ The address of the StandardGovernor contract.
     * @param cashToken_ The address of the CashToken contract.
     * @return The address of the deployed PowerToken contract.
     */
    function deploy(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_
    ) external onlyZeroGovernor returns (address) {
        ++nonce;
        return lastDeploy = address(new PowerToken(bootstrapToken_, standardGovernor_, cashToken_, vault));
    }

    /// @inheritdoc IDeployer
    function nextDeploy() external view returns (address) {
        return ContractHelper.getContractFrom(address(this), nonce + 1);
    }
}
