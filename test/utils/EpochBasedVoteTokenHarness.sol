// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { EpochBasedVoteToken } from "../../src/EpochBasedVoteToken.sol";

contract EpochBasedVoteTokenHarness is EpochBasedVoteToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) EpochBasedVoteToken(name_, symbol_, uint8(decimals_)) {}

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }
}
