// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @title A Deterministic deployer of Emergency Governor contracts using CREATE.
interface IEmergencyGovernorDeployer {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /// @notice Revert message when the Registrar specified in the constructor is address(0).
    error InvalidRegistrarAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the caller is not the Zero Governor.
    error NotZeroGovernor();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Deploys a new instance of an Emergency Governor.
     * @param  powerToken       The address of some Power Token that will be used by voters.
     * @param  standardGovernor The address of some Standard Governor.
     * @param  thresholdRatio   The threshold ratio to use for proposals.
     * @return deployed         The address the deployed Emergency Governor.
     */
    function deploy(
        address powerToken,
        address standardGovernor,
        uint16 thresholdRatio
    ) external returns (address deployed);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /// @notice Returns the address of the last Emergency Governor deployed by this contract.
    function lastDeploy() external view returns (address lastDeploy);

    /// @notice Returns the address of the new Emergency Governor this contract will deploy
    function nextDeploy() external view returns (address nextDeploy);

    /// @notice Returns the address of the Registrar.
    function registrar() external view returns (address registrar);

    /// @notice Returns the address of the Zero Governor.
    function zeroGovernor() external view returns (address zeroGovernor);
}
