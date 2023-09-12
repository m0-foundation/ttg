// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { EpochBasedInflationaryVoteToken } from "../src/EpochBasedInflationaryVoteToken.sol";

contract EpochBasedInflationaryVoteTokenHarness is EpochBasedInflationaryVoteToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 participationInflation_,
        address governor_
    ) EpochBasedInflationaryVoteToken(name_, symbol_, participationInflation_, governor_) {}

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }
}
