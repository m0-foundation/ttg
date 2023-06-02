// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IProtocolConfigurator} from "src/interfaces/IProtocolConfigurator.sol";

/**
 * @title ProtocolConfigurator
 * @dev Provide governed config contracts for the SPOG
 */
contract ProtocolConfigurator is IProtocolConfigurator {
    // List of named config contracts managed by SPOG governance
    // hashed name => ConfigContract
    mapping(bytes32 => ConfigContract) private config;

    function changeConfig(bytes32 configName, address configAddress, bytes4 interfaceId) public virtual override {
        if (configName == bytes32(0)) {
            revert ConfigNameCannotBeZero();
        }

        // check that the contract supports the interfaceId provided
        // Note: This also protect against adddress(0)
        if (!ERC165(configAddress).supportsInterface(interfaceId)) {
            revert ConfigERC165Unsupported();
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

    function getConfig(bytes32 name) public view override returns (address, bytes4) {
        return (config[name].contractAddress, config[name].interfaceId);
    }
}
