// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import { ERC20, ERC20Permit, ERC20Snapshot, ERC20Votes } from "../ImportedContracts.sol";

import { IComptroller } from "../comptroller/IComptroller.sol";
import { IVALUE } from "./ITokens.sol";

import { ERC20, ERC20Permit, ERC20Snapshot, ERC20Votes } from "../ImportedContracts.sol";
import { ControlledByComptroller } from "../comptroller/ControlledByComptroller.sol";

/// @title VALUE ERC20 token with a built-in snapshot functionality
/// @dev Snapshot is taken at the moment of reset by Comptroller
/// @dev This snapshot is used by new Vote token to set initial supply of tokens
/// @dev All value holders become vote holders of the new Vote governance
contract VALUE is IVALUE, ERC20Votes, ERC20Snapshot, ControlledByComptroller {
    constructor(
        string memory name,
        string memory symbol,
        address comptroller_
    ) ControlledByComptroller(comptroller_) ERC20(name, symbol) ERC20Permit(name) {}

    modifier onlyGovernor() {
        if (msg.sender != IComptroller(comptroller).governor()) revert CallerIsNotGovernor();
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
        if (msg.sender != comptroller) revert CallerIsNotComptroller();

        return _snapshot();
    }

    /// @notice Restricts minting to the governor.
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public onlyGovernor {
        _mint(to, amount);
    }
}
