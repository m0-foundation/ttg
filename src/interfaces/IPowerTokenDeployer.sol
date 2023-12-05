// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @title A Deterministic deployer of Power Token contracts using CREATE.
interface IPowerTokenDeployer {
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
     * @return deployed         The address the deployed Emergency Governor.
     */
    function deploy(
        address bootstrapToken,
        address standardGovernor,
        address cashToken
    ) external returns (address deployed);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the address of the last Power Token deployed by this contract.
     * @return Last deployed Power Token address.
     */
    function lastDeploy() external view returns (address);

    /**
     * @notice Returns the address of the new Power Token this contract will deploy
     * @return Next deployed Power Token address.
     */
    function nextDeploy() external view returns (address);

    /**
     * @notice Returns the address of the Vault.
     * @return The Vault address.
     */
    function vault() external view returns (address);
}
