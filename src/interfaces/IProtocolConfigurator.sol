// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IProtocolConfigurator {
    event ConfigChange(bytes32 indexed configName, address contractAddress, bytes4 interfaceId);

    error ConfigInterfaceIdMismatch();
    error ConfigERC165Unsupported();
    error ConfigNameCannotBeZero();

    struct ConfigContract {
        address contractAddress;
        bytes4 interfaceId;
    }

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId) external;

    function getConfig(bytes32 name) external view returns (address, bytes4);
}
