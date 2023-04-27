// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IList} from "src/interfaces/IList.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

/**
 * @title SPOGGoverned
 * @dev An abstract contract that provides a function for getting a list contract instance.
 */
abstract contract SPOGGoverned {
    error InvalidList(address listAddress);

    ISPOG public spog;

    /**
     * @dev Initializes the SPOG contract address.
     * @param _spog The address of the SPOG contract.
     */
    constructor(address _spog) {
        spog = ISPOG(_spog);
    }

    /**
     * @dev Returns the list contract instance for a given address.
     * @param listAddress The address of the list contract.
     * @return The list contract instance.
     */
    function getListByAddress(address listAddress) public view returns (IList) {
        if (!spog.isListInMasterList(listAddress)) {
            revert InvalidList(listAddress);
        }

        return IList(listAddress);
    }
}
