// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @title A book of record of SPOG-specific contracts and arbitrary key-value pairs and lists.
interface IRegistrar {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /// @notice Revert message when the Vault retrieved in the constructor is address(0).
    error InvalidVaultAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the Zero Token retrieved in the constructor is address(0).
    error InvalidZeroTokenAddress();

    /// @notice Revert message when the caller is not the Standard Governor nor the Emergency Governor.
    error NotStandardOrEmergencyGovernor();

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    /**
     * @notice Emitted when `account` is added to `list`.
     * @param  list    The key for the list.
     * @param  account The address of the added account.
     */
    event AddressAddedToList(bytes32 indexed list, address indexed account);

    /**
     * @notice Emitted when `account` is removed from `list`.
     * @param  list    The key for the list.
     * @param  account The address of the removed account.
     */
    event AddressRemovedFromList(bytes32 indexed list, address indexed account);

    /**
     * @notice Emitted when `key` is set to `value`.
     * @param  key   The key.
     * @param  value The value.
     */
    event KeySet(bytes32 indexed key, bytes32 indexed value);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Adds `account` to `list`.
     * @param  list    The key for some list.
     * @param  account The address of some account to be added.
     */
    function addToList(bytes32 list, address account) external;

    /**
     * @notice Removes `account` from `list`.
     * @param  list    The key for some list.
     * @param  account The address of some account to be removed.
     */
    function removeFromList(bytes32 list, address account) external;

    /**
     * @notice Sets `key` to `value`.
     * @param  key   Some key.
     * @param  value Some value.
     */
    function setKey(bytes32 key, bytes32 value) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /// @notice Returns the address of the Emergency Governor.
    function emergencyGovernor() external view returns (address emergencyGovernor);

    /// @notice Returns the address of the Emergency Governor Deployer.
    function emergencyGovernorDeployer() external view returns (address emergencyGovernorDeployer);

    /**
     * @notice Returns the value of `key`.
     * @param  key   Some key.
     * @param  value Some value.
     */
    function get(bytes32 key) external view returns (bytes32 value);

    /**
     * @notice Returns the values of `keys` respectively.
     * @param  keys   Some keys.
     * @param  values Some values.
     */
    function get(bytes32[] calldata keys) external view returns (bytes32[] memory values);

    /**
     * @notice Returns whether `list` contains `account`.
     * @param  list     The key for some list.
     * @param  account  The address of some account.
     * @return contains Whether `list` contains `account`.
     */
    function listContains(bytes32 list, address account) external view returns (bool contains);

    /**
     * @notice Returns whether `list` contains all specified accounts.
     * @param  list     The key for some list.
     * @param  accounts An array of addressed of some accounts.
     * @return contains Whether `list` contains all specified accounts.
     */
    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool contains);

    /// @notice Returns the address of the Power Token.
    function powerToken() external view returns (address powerToken);

    /// @notice Returns the address of the Power Token Deployer.
    function powerTokenDeployer() external view returns (address powerTokenDeployer);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address standardGovernor);

    /// @notice Returns the address of the Standard Governor Deployer.
    function standardGovernorDeployer() external view returns (address standardGovernorDeployer);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address vault);

    /// @notice Returns the address of the Zero Governor.
    function zeroGovernor() external view returns (address zeroGovernor);

    /// @notice Returns the address of the Zero Token.
    function zeroToken() external view returns (address zeroToken);
}
