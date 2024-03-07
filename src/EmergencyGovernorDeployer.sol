// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { IDeployer, IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";

import { EmergencyGovernor } from "./EmergencyGovernor.sol";

/**
 * @title  A Deterministic deployer of Emergency Governor contracts using CREATE.
 * @author M^0 Labs
 */
contract EmergencyGovernorDeployer is IEmergencyGovernorDeployer {
    /* ============ Variables ============ */

    /// @inheritdoc IEmergencyGovernorDeployer
    address public immutable registrar;

    /// @inheritdoc IEmergencyGovernorDeployer
    address public immutable zeroGovernor;

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
     * @notice Constructs a new EmergencyGovernorDeployer contract.
     * @param  zeroGovernor_ The address of the ZeroGovernor contract.
     * @param  registrar_    The address of the Registrar contract.
     */
    constructor(address zeroGovernor_, address registrar_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();
        if ((registrar = registrar_) == address(0)) revert InvalidRegistrarAddress();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IEmergencyGovernorDeployer
    function deploy(
        address powerToken_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) external onlyZeroGovernor returns (address) {
        unchecked {
            ++nonce;
        }

        return
            lastDeploy = address(
                new EmergencyGovernor(powerToken_, zeroGovernor, registrar, standardGovernor_, thresholdRatio_)
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
