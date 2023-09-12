// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IRegistrar {
    // Events
    event AddressAddedToList(bytes32 indexed list, address indexed account);
    event AddressRemovedFromList(bytes32 indexed list, address indexed account);
    event ConfigUpdated(bytes32 indexed key, bytes32 indexed value);
    event ResetExecuted();

    // Errors
    error CallerIsNotGovernor();

    // Info functions about double governance
    function governor() external view returns (address governor);

    function dualGovernorDeployer() external view returns (address dualGovernorDeployer);

    function zeroTokenDeployer() external view returns (address zeroTokenDeployer);

    // Accepted `proposal` functions
    function addToList(bytes32 list, address account) external;

    function removeFromList(bytes32 list, address account) external;

    function updateConfig(bytes32 key, bytes32 value) external;

    function reset() external;

    // Registry functions
    function get(bytes32 key) external view returns (bytes32 value);

    function get(bytes32[] calldata keys) external view returns (bytes32[] memory values);

    function listContains(bytes32 list, address account) external view returns (bool contains);
}
