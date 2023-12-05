// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @title A Deterministic deployer of Standard Governor contracts using CREATE.
interface IStandardGovernorDeployer {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

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

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Deploys a new instance of an Standard Governor.
     * @param  powerToken                       The address of some Power Token that will be used by voters.
     * @param  emergencyGovernor                The address of some Emergency Governor.
     * @param  cashToken                        The address of some Cash Token.
     * @param  proposalFee                      The proposal fee required to create proposals.
     * @param  maxTotalZeroRewardPerActiveEpoch The maximum amount of Zero Token rewarded per active epoch.
     * @return deployed                         The address the deployed Standard Governor.
     */
    function deploy(
        address powerToken,
        address emergencyGovernor,
        address cashToken,
        uint256 proposalFee,
        uint256 maxTotalZeroRewardPerActiveEpoch
    ) external returns (address deployed);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the address of the last Standard Governor deployed by this contract.
     * @return Last deployed Standard Governor address.
     */
    function lastDeploy() external view returns (address);

    /**
     * @notice Returns the address of the new Standard Governor this contract will deploy
     * @return Next deployed Standard Governor address.
     */
    function nextDeploy() external view returns (address);

    /**
     * @notice Returns the address of the Registrar.
     * @return Registrar address.
     */
    function registrar() external view returns (address);

    /**
     * @notice Returns the address of the Vault.
     * @return Vault address.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns the address of the Zero Governor.
     * @return Zero Governor address.
     */
    function zeroGovernor() external view returns (address);

    /**
     * @notice Returns the address of the Zero Token.
     * @return Zero Token address.
     */
    function zeroToken() external view returns (address);
}
