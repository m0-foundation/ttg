// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IDeployer } from "./IDeployer.sol";

/**
 * @title  A Deterministic deployer of Standard Governor contracts using CREATE.
 * @author M^0 Labs
 */
interface IStandardGovernorDeployer is IDeployer {
    /* ============ Custom Errors ============ */

    /// @notice Revert message when the Registrar specified in the constructor is address(0).
    error InvalidRegistrarAddress();

    /// @notice Revert message when the Vault specified in the constructor is address(0).
    error InvalidVaultAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the Zero Token specified in the constructor is address(0).
    error InvalidZeroTokenAddress();

    /// @notice Revert message when the caller is not the Zero Governor.
    error NotZeroGovernor();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Deploys a new instance of a Standard Governor.
     * @param  powerToken                       The address of some Power Token that will be used by voters.
     * @param  emergencyGovernor                The address of some Emergency Governor.
     * @param  cashToken                        The address of some Cash Token.
     * @param  proposalFee                      The proposal fee required to create proposals.
     * @param  maxTotalZeroRewardPerActiveEpoch The maximum amount of Zero Token rewarded per active epoch.
     * @return The address of the deployed Standard Governor.
     */
    function deploy(
        address powerToken,
        address emergencyGovernor,
        address cashToken,
        uint256 proposalFee,
        uint256 maxTotalZeroRewardPerActiveEpoch
    ) external returns (address);

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the address of the Registrar.
    function registrar() external view returns (address);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address);

    /// @notice Returns the address of the Zero Governor.
    function zeroGovernor() external view returns (address);

    /// @notice Returns the address of the Zero Token.
    function zeroToken() external view returns (address);
}
