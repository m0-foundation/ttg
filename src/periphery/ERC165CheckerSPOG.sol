// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ERC165Checker } from "src/ImportedContracts.sol";

import { ISPOG } from "src/interfaces/ISPOG.sol";

/**
 * @title ERC165CheckerSPOG
 *
 * Utility to verify whether an address implements ISPOG.
 */
abstract contract ERC165CheckerSPOG {
    error InvalidSPOGInterface();

    /// Only proceed if SPOG implements ISPOG interface
    /// @param spogAddress address to check
    modifier onlySPOGInterface(address spogAddress) {
        _checkSPOGInterface(spogAddress);
        _;
    }

    function checkSPOGInterface(address spogAddress) public view {
        _checkSPOGInterface(spogAddress);
    }

    function _checkSPOGInterface(address spogAddress) internal view {
        if (!ERC165Checker.supportsInterface(spogAddress, type(ISPOG).interfaceId)) {
            revert InvalidSPOGInterface();
        }
    }
}
