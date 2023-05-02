// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.20;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {SPOGVotes} from "./SPOGVotes.sol";
import {IValueToken} from "src/interfaces/tokens/IValueToken.sol";

/// @title ValueToken
/// @dev Main token of value governance, has a built-in snapshot functionality.
/// @dev Snapshot is taken at the moment of reset by SPOG.
/// @dev This snapshot is used by new Vote token to set initial supply of tokens.
/// @dev All value holders become vote holders of the new Vote governance.
contract ValueToken is SPOGVotes, ERC20Snapshot, IValueToken {
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

    /// @dev Takes a snapshot of account balances and returns snapshot id.
    function snapshot() external override returns (uint256) {
        if (msg.sender != spogAddress) revert CallerIsNotSPOG();
        return _snapshot();
    }
}
