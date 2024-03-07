// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IDeployer, IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";

import { PowerToken } from "./PowerToken.sol";

/**
 * @title  A Deterministic deployer of Power Token contracts using CREATE.
 * @author M^0 Labs
 */
contract PowerTokenDeployer is IPowerTokenDeployer {
    /* ============ Variables ============ */

    /// @inheritdoc IPowerTokenDeployer
    address public immutable vault;

    /// @inheritdoc IPowerTokenDeployer
    address public immutable zeroGovernor;

    /// @inheritdoc IDeployer
    address public lastDeploy;

    /// @inheritdoc IDeployer
    uint256 public nonce;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new PowerTokenDeployer contract.
     * @param  zeroGovernor_ The address of the ZeroGovernor contract.
     * @param  vault_        The address of the Vault contract.
     */
    constructor(address zeroGovernor_, address vault_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPowerTokenDeployer
    function deploy(address bootstrapToken_, address standardGovernor_, address cashToken_) external returns (address) {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();

        unchecked {
            ++nonce;
        }

        return lastDeploy = address(new PowerToken(bootstrapToken_, standardGovernor_, cashToken_, vault));
    }

    /// @inheritdoc IDeployer
    function nextDeploy() external view returns (address) {
        unchecked {
            return ContractHelper.getContractFrom(address(this), nonce + 1);
        }
    }
}
