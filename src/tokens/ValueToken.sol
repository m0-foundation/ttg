// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "src/tokens/SPOGVotes.sol";

/// @title ValueToken with a built-in snapshot functionality
/// @dev Snapshot is taken at the moment of reset by SPOG
/// @dev This snapshot is used by new Vote token to set initial supply of tokens
/// @dev All value holders become vote holders of the new Vote governance
contract ValueToken is SPOGVotes, ERC20Votes, ERC20Snapshot, IValue {
    constructor(string memory name, string memory symbol) SPOGVotes(name, symbol) {}

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Votes)
    {
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
    function snapshot() external override returns (uint256) {
        if (msg.sender != spog) revert CallerIsNotSPOG();
        return _snapshot();
    }

    /// @notice Restricts minting to address with MINTER_ROLE
    /// @param to The address to mint to
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) public override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
