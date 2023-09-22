// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IRegistrar {
    event AddressAddedToList(bytes32 indexed list, address indexed account);

    event AddressRemovedFromList(bytes32 indexed list, address indexed account);

    event ConfigUpdated(bytes32 indexed key, bytes32 indexed value);

    event ResetExecuted();

    error CallerIsNotGovernor();

    function addToList(bytes32 list, address account) external;

    function dualGovernorDeployer() external view returns (address dualGovernorDeployer);

    function get(bytes32 key) external view returns (bytes32 value);

    function get(bytes32[] calldata keys) external view returns (bytes32[] memory values);

    function governor() external view returns (address governor);

    function listContains(bytes32 list, address account) external view returns (bool contains);

    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool contains);

    function removeFromList(bytes32 list, address account) external;

    function reset() external;

    function updateConfig(bytes32 key, bytes32 value) external;

    function zeroTokenDeployer() external view returns (address zeroTokenDeployer);
}
