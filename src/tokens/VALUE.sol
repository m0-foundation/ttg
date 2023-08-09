// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import { IRegistrar } from "../registrar/IRegistrar.sol";
import { IVALUE } from "./ITokens.sol";

import { ERC20, ERC20Permit, ERC20Snapshot, ERC20Votes } from "../ImportedContracts.sol";
import { ControlledByRegistrar } from "../registrar/ControlledByRegistrar.sol";

/// @title VALUE ERC20 token with a built-in snapshot functionality
/// @dev Snapshot is taken at the moment of reset by Registrar
/// @dev This snapshot is used by new Vote token to set initial supply of tokens
/// @dev All value holders become vote holders of the new Vote governance
contract VALUE is IVALUE, ERC20Votes, ERC20Snapshot, ControlledByRegistrar {
    constructor(
        string memory name,
        string memory symbol,
        address registrar_
    ) ControlledByRegistrar(registrar_) ERC20(name, symbol) ERC20Permit(name) {}

    modifier onlyGovernor() {
        if (msg.sender != IRegistrar(registrar).governor()) revert CallerIsNotGovernor();
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);

        // Automatically delegate to self if not already delegated
        if (delegates(to) == address(0)) {
            _delegate(to, to);
        }
    }

    function _burn(address account, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Votes) {
        super._mint(account, amount);
    }

    /// @notice Takes a snapshot of account balances and returns snapshot id
    /// @return The snapshot id
    function snapshot() external returns (uint256) {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        return _snapshot();
    }

    /// @notice Restricts minting to the governor.
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyGovernor {
        _mint(to, amount);
    }
}
