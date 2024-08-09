// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  A book of record of arbitrary key-value pairs and lists.
 * @author M^0 Labs
 */
interface IRegistrar {
    /* ============ Events ============ */

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

    /* ============ Custom Errors ============ */

    /// @notice Revert message when the Portal in the constructor is address(0).
    error ZeroPortal();

    /// @notice Revert message when the caller is not the Portal.
    error NotPortal();

    /* ============ Interactive Functions ============ */

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

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns the value of `key`.
     * @param  key Some key.
     * @return Some value.
     */
    function get(bytes32 key) external view returns (bytes32);

    /**
     * @notice Returns the values of `keys` respectively.
     * @param  keys Some keys.
     * @return Some values.
     */
    function get(bytes32[] calldata keys) external view returns (bytes32[] memory);

    /**
     * @notice Returns whether `list` contains `account`.
     * @param  list    The key for some list.
     * @param  account The address of some account.
     * @return Whether `list` contains `account`.
     */
    function listContains(bytes32 list, address account) external view returns (bool);

    /**
     * @notice Returns whether `list` contains all specified accounts.
     * @param  list     The key for some list.
     * @param  accounts An array of addressed of some accounts.
     * @return Whether `list` contains all specified accounts.
     */
    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool);

    /// @notice Returns the address of the Portal.
    function portal() external view returns (address);
}
