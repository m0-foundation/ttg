// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.19;

import { ERC20Votes } from "../ImportedContracts.sol";

/// @title Abstract extension of ERC20Votes that enables auto-delegation-to-self
/// @dev Overrides _afterTokenTransfer
abstract contract AutoDelegatedVotes is ERC20Votes {
    /**
     * @dev Move voting power when tokens are transferred, 
     * and automatically delegate to self if not already delegated.
     *
     *
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        // We only need to handle the simple case where the user isn't currently delegating to anyone,
        // as the super of this function already moves voting power appropriately for pre-delegated users.
        if (delegates(to) == address(0)) {
            _delegate(to, to);
        }
    }
}
