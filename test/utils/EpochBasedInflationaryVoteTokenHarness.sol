// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

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

    function inflationIndexOf(address account_, uint256 index_) external view returns (uint256 inflationIndex_) {
        AmountEpoch[] storage inflationIndices = _inflationIndices[account_];
        inflationIndex_ = inflationIndices[index_].amount;
    }

    function delegateeInflationIndexOf(
        address delegatee_,
        uint256 index_
    ) external view returns (uint256 inflationIndex_) {
        AmountEpoch[] storage inflationIndices = _delegateeInflationIndices[delegatee_];
        inflationIndex_ = inflationIndices[index_].amount;
    }
}
