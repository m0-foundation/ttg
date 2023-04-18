// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import "./SPOGVotes.sol";

contract ValueToken is ERC20Snapshot, SPOGVotes {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    constructor(string memory name, string memory symbol) SPOGVotes(name, symbol) {
        // _setupRole(SNAPSHOT_ROLE, _msgSender());
    }

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

    function snapshot()
        public
        returns (
            // onlyRole(SNAPSHOT_ROLE)
            uint256
        )
    {
        return _snapshot();
    }
}
