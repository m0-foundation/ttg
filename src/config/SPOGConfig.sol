// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ISPOGConfig} from "src/interfaces/ISPOGConfig.sol";

/**
 * @title SPOGConfig
 * @dev An abstract contract to provide config contracts for the SPOG
 */
abstract contract SPOGConfig is ISPOGConfig {
    // List of named config contracts managed by SPOG governance
    // hashed name => ConfigContract
    mapping(bytes32 => ConfigContract) private config;

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId) public virtual {
        // check that the contract supports the interfaceId provided
        if (!ERC165(configAddress).supportsInterface(interfaceId)) {
            revert ConfigERC165Unsupported();
        }

        if (configName == bytes32(0)) {
            revert ConfigNameCannotBeZero();
        }

        //check if named config already exists
        if (config[configName].contractAddress != address(0)) {
            //if it exists, make sure the new contract interface matches
            if (config[configName].interfaceId != interfaceId) {
                revert ConfigInterfaceIdMismatch();
            }
        }

        config[configName] = ConfigContract(configAddress, interfaceId);

        emit ConfigChange(configName, configAddress, interfaceId);
    }

    function getConfig(bytes32 name) public view returns (address, bytes4) {
        return (config[name].contractAddress, config[name].interfaceId);
    }
}
