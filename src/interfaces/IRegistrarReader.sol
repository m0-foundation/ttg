// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

interface IRegistrarReader {
    /* ============ Errors ============ */
    error InvalidRegistrarAddress();

    /* ============ View/Pure Functions ============ */

     /**
     * @notice Returns the value of `key`.
     * @dev This is a passthrough to the `get` function on the Registrar contract for convenience.
     * @param  key Some key.
     * @return Some value.
     */
    function get(bytes32 key) external view returns (bytes32);

    /**
     * @notice Returns the values of `keys` respectively.
     * @dev This is a passthrough to the `get` function on the Registrar contract for convenience.
     * @param  keys Some keys.
     * @return Some values.
     */
    function get(bytes32[] calldata keys) external view returns (bytes32[] memory);

    /**
     * @notice Returns whether `list` contains `account`.
     * @dev This uses the standard list functionality of the Registrar contract and is included here for convenience.
     * @param  list    The key for some list.
     * @param  account The address of some account.
     * @return Whether `list` contains `account`.
     */
    function listContains(bytes32 list, address account) external view returns (bool);

    /**
     * @notice Returns whether `list` contains all specified accounts.
     * @dev This uses the standard list functionality of the Registrar contract and is included here for convenience.
     * @param  list     The key for some list.
     * @param  accounts An array of addressed of some accounts.
     * @return Whether `list` contains all specified accounts.
     */
    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool);

    /**
     * @notice Returns whether `list` contains `account`.
     * @dev bytes32 lists are not natively supported by the Registrar contract.
     *      This implementation assumes that the values are added to the Registrar
     *      using the generic `setKey` function where the key provided is calculated
     *      as `keccak256(abi.encodePacked(list, account))` and the value is treated
     *      as a boolean (i.e. `bytes32(uint256(1))` for true and `bytes32(0)` for false).
     * @param  list    The key for some list.
     * @param  account The address of some account.
     * @return Whether `list` contains `account`.
     */
    function listContains(bytes32 list, bytes32 account) external view returns (bool);

    /**
     * @notice Returns whether `list` contains all specified accounts.
     * @dev bytes32 lists are not natively supported by the Registrar contract.
     *      This implementation assumes that the values are added to the Registrar
     *      using the generic `setKey` function where the key provided is calculated
     *      as `keccak256(abi.encodePacked(list, account))` and the value is treated
     *      as a boolean (i.e. `bytes32(uint256(1))` for true and `bytes32(0)` for false).
     * @dev Returns "true" for empty list. This is done to be consistent with the behavior of the
     *      `listContains` function for address lists on the Registrar.
     * @param  list     The key for some list.
     * @param  accounts An array of addressed of some accounts.
     * @return Whether `list` contains all specified accounts.
     */
    function listContains(bytes32 list, bytes32[] calldata accounts) external view returns (bool);
}
