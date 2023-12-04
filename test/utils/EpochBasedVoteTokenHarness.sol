// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { EpochBasedVoteToken } from "../../src/abstract/EpochBasedVoteToken.sol";

contract EpochBasedVoteTokenHarness is EpochBasedVoteToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) EpochBasedVoteToken(name_, symbol_, uint8(decimals_)) {}

    function pushBalance(address account_, uint256 startingEpoch_, uint256 balance_) external {
        _balances[account_].push(AmountWindow(uint16(startingEpoch_), uint240(balance_)));
    }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }
}
