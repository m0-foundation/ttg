// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IRegistrar {
    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event AddressAddedToList(bytes32 indexed list, address indexed account);

    event AddressRemovedFromList(bytes32 indexed list, address indexed account);

    event ConfigUpdated(bytes32 indexed key, bytes32 indexed value);

    event ResetExecuted();

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error CallerIsNotGovernor();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function removeFromList(bytes32 list, address account) external;

    function reset() external;

    function updateConfig(bytes32 key, bytes32 value) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function get(bytes32 key) external view returns (bytes32 value);

    function get(bytes32[] calldata keys) external view returns (bytes32[] memory values);

    function governor() external view returns (address governor);

    function governorDeployer() external view returns (address governorDeployer);

    function listContains(bytes32 list, address account) external view returns (bool contains);

    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool contains);

    function powerTokenDeployer() external view returns (address powerTokenDeployer);

    function vault() external view returns (address vault);

    function zeroToken() external view returns (address zeroToken);
}
