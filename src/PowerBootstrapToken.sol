// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IPowerBootstrapToken } from "./interfaces/IPowerBootstrapToken.sol";

// NOTE: This is an example of a token that can be used to bootstrap the PowerToken for the first time.

contract PowerBootstrapToken is IPowerBootstrapToken {
    function balanceOfAt(address account_, uint256 epoch_) external pure returns (uint256 balance_) {
        // TODO: Create more if-returns to define more initial PowerToken starting balances.
        if (account_ == address(1)) return 1_000;

        return 0;
    }

    function totalSupplyAt(uint256 epoch_) external pure returns (uint256 totalSupply_) {
        // TODO: Ensure that the total supply is equal to the sum of all initial PowerToken starting balances.
        totalSupply_ = 1_000;
    }
}
