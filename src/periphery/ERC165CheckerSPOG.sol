// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

/**
 * @title ERC165CheckerSPOG

 * Utility to verify whether an address implements ISPOG.
 */

abstract contract ERC165CheckerSPOG {
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
        require(
            ERC165Checker.supportsInterface(
                spogAddress,
                type(ISPOG).interfaceId
            ),
            "ERC165CheckerSPOG: spogAddress address does not implement proper interface"
        );
    }
}
