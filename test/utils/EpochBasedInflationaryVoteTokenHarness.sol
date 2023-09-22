// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { EpochBasedInflationaryVoteToken } from "../../src/EpochBasedInflationaryVoteToken.sol";

contract EpochBasedInflationaryVoteTokenHarness is EpochBasedInflationaryVoteToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 participationInflation_
    ) EpochBasedInflationaryVoteToken(name_, symbol_, participationInflation_) {}

    function markParticipation(address delegatee_) external {
        _markParticipation(delegatee_);
    }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }
}
