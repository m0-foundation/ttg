// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IRegistrar {
    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event AddressAddedToList(bytes32 indexed list, address indexed account);

    event AddressRemovedFromList(bytes32 indexed list, address indexed account);

    event ConfigUpdated(bytes32 indexed key, bytes32 indexed value);

    event ResetExecuted(address indexed bootstrapToken);

    event EphemeralContractsDeployed(
        address indexed standardGovernor,
        address indexed emergencyGovernor,
        address indexed powerToken
    );

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error CallerIsNotStandardOrEmergencyGovernor();

    error CallerIsNotZeroGovernor();

    error InvalidEmergencyGovernorDeployerAddress();

    error InvalidPowerTokenDeployerAddress();

    error InvalidStandardGovernorDeployerAddress();

    error InvalidZeroGovernorAddress();

    error UnexpectedPowerTokenDeployed(address expected, address deployed);

    error UnexpectedStandardGovernorDeployed(address expected, address deployed);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function removeFromList(bytes32 list, address account) external;

    function reset(address bootstrapToken_) external;

    function updateConfig(bytes32 key, bytes32 value) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function emergencyGovernor() external view returns (address emergencyGovernor);

    function emergencyGovernorDeployer() external view returns (address emergencyGovernorDeployer);

    function get(bytes32 key) external view returns (bytes32 value);

    function get(bytes32[] calldata keys) external view returns (bytes32[] memory values);

    function listContains(bytes32 list, address account) external view returns (bool contains);

    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool contains);

    function powerToken() external view returns (address powerToken);

    function powerTokenDeployer() external view returns (address powerTokenDeployer);

    function standardGovernor() external view returns (address standardGovernor);

    function standardGovernorDeployer() external view returns (address standardGovernorDeployer);

    function vault() external view returns (address vault);

    function zeroGovernor() external view returns (address zeroGovernor);

    function zeroToken() external view returns (address zeroToken);
}
