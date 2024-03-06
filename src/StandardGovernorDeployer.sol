// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IDeployer, IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";

import { StandardGovernor } from "./StandardGovernor.sol";

/**
 * @title  A Deterministic deployer of Standard Governor contracts using CREATE.
 * @author M^0 Labs
 */
contract StandardGovernorDeployer is IStandardGovernorDeployer {
    /* ============ Variables ============ */

    /// @inheritdoc IStandardGovernorDeployer
    address public immutable registrar;

    /// @inheritdoc IStandardGovernorDeployer
    address public immutable vault;

    /// @inheritdoc IStandardGovernorDeployer
    address public immutable zeroGovernor;

    /// @inheritdoc IStandardGovernorDeployer
    address public immutable zeroToken;

    /// @inheritdoc IDeployer
    address public lastDeploy;

    /// @inheritdoc IDeployer
    uint256 public nonce;

    /* ============ Modifiers ============ */

    /// @dev Throws if called by any contract other than the Zero Governor.
    modifier onlyZeroGovernor() {
        if (msg.sender != zeroGovernor) revert NotZeroGovernor();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs a new StandardGovernorDeployer contract.
     * @param  zeroGovernor_ The address of the ZeroGovernor contract.
     * @param  registrar_    The address of the Registrar contract.
     * @param  vault_        The address of the Vault contract.
     * @param  zeroToken_    The address of the ZeroToken contract.
     */
    constructor(address zeroGovernor_, address registrar_, address vault_, address zeroToken_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IStandardGovernorDeployer
    function deploy(
        address powerToken_,
        address emergencyGovernor_,
        address cashToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) external onlyZeroGovernor returns (address) {
        unchecked {
            ++nonce;
        }

        return
            lastDeploy = address(
                new StandardGovernor(
                    powerToken_,
                    emergencyGovernor_,
                    zeroGovernor,
                    cashToken_,
                    registrar,
                    vault,
                    zeroToken,
                    proposalFee_,
                    maxTotalZeroRewardPerActiveEpoch_
                )
            );
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IDeployer
    function nextDeploy() external view returns (address) {
        unchecked {
            return ContractHelper.getContractFrom(address(this), nonce + 1);
        }
    }
}
