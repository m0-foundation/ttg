// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ISPOG } from "../interfaces/ISPOG.sol";
import { ISPOGToken } from "../interfaces/ITokens.sol";

import { AccessControlEnumerable } from "../ImportedContracts.sol";

abstract contract SPOGToken is AccessControlEnumerable, ISPOGToken {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public spog;

    constructor() {
        // TODO: Who will be the admin of this contract?
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Sets the spog address. Can only be called once.
    /// @param spog_ the address of the spog
    function initializeSPOG(address spog_) external {
        if (spog != address(0)) revert AlreadyInitialized();

        spog = spog_;

        _setupRole(MINTER_ROLE, spog);
        // _setupRole(MINTER_ROLE, ISPOG(spog).governor());
    }
}
