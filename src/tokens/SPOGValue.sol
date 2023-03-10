// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Unsure if access for minting is needed. Perhaps the solution is to allow only SPOG to mint $VALUE
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/// @title SPOGValue: $Value token used within SPOG governance
contract SPOGValue is
    ERC20,
    ERC20Permit,
    ERC20Burnable,
    AccessControlEnumerable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Initializes the contract by creating the token as well as the default admin role and the SPOG role
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) {}

    /// @dev Creates `amount` new tokens for `to`.
    ///
    /// See {ERC20-_mint}.
    ///
    /// Requirements:
    ///
    /// - the caller must have the `MINTER_ROLE`.
    ///
    function mint(
        address to,
        uint256 amount
    ) public virtual onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
