// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "src/interfaces/IList.sol";
import "src/interfaces/ISPOG.sol";

/**
 * @title SPOGGoverned
 * @notice An abstract contract that provides a function for getting a list contract instance.
 */
abstract contract SPOGGoverned {
    error InvalidList(address list);

    ISPOG public spog;

    /**
     * @notice Initializes the SPOG contract address.
     * @param _spog The address of the SPOG contract.
     */
    constructor(address _spog) {
        spog = ISPOG(_spog);
    }

    /**
     * @notice Returns the list contract instance for a given address.
     * @param list The address of the list contract.
     * @return The list contract instance.
     */
    function getListByAddress(address list) public view returns (IList) {
        if (!spog.isListInMasterList(list)) revert InvalidList(list);

        return IList(list);
    }

    /**
     * @notice Returns the address and ERC165 interface id of config.
     * @param name The name of config.
     * @return Config address and interface identifier.
     */
    function getConfigByName(bytes32 name) public view returns (address, bytes4) {
        return spog.getConfig(name);
    }
}
