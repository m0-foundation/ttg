// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IDeployer } from "./IDeployer.sol";

/// @title A Deterministic deployer of Power Token contracts using CREATE.
interface IPowerTokenDeployer is IDeployer {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /// @notice Revert message when the Vault specified in the constructor is address(0).
    error InvalidVaultAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the caller is not the Zero Governor.
    error NotZeroGovernor();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Deploys a new instance of a Power Token.
     * @param  bootstrapToken   The address of some token to bootstrap from.
     * @param  standardGovernor The address of some Standard Governor.
     * @param  cashToken        The address of some Cash Token.
     * @return The address of the deployed Emergency Governor.
     */
    function deploy(address bootstrapToken, address standardGovernor, address cashToken) external returns (address);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the address of the Vault.
     * @return The Vault address.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns the address of the Zero Governor.
     * @return The Zero Governor address.
     */
    function zeroGovernor() external view returns (address);
}
