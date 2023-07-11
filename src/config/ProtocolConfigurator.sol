// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IERC165 } from "../interfaces/ImportedInterfaces.sol";
import { IProtocolConfigurator } from "../interfaces/IProtocolConfigurator.sol";

/**
 * @title ProtocolConfigurator
 * @dev Provide governed config contracts for the SPOG
 */
contract ProtocolConfigurator is IProtocolConfigurator {

    // List of named config contracts managed by SPOG governance
    // hashed name => ConfigContract
    mapping(bytes32 => ConfigContract) private config;

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId) public virtual {
        if (configName == bytes32(0)) revert ConfigNameCannotBeZero();

        // check that the contract supports the interfaceId provided
        // Note: This also protect against address(0)
        if (!IERC165(configAddress).supportsInterface(interfaceId)) revert ConfigERC165Unsupported();

        // check if named config already exists, and if so, make sure the new contract address matches
        if (config[configName].contractAddress != address(0) && config[configName].interfaceId != interfaceId) {
            revert ConfigInterfaceIdMismatch();
        }

        config[configName] = ConfigContract(configAddress, interfaceId);

        emit ConfigChange(configName, configAddress, interfaceId);
    }

    function getConfig(bytes32 name) public view returns (address, bytes4) {
        return (config[name].contractAddress, config[name].interfaceId);
    }

}
