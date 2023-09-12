// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IZeroToken } from "./interfaces/IZeroToken.sol";

import { EpochBasedMintableVoteToken } from "./EpochBasedMintableVoteToken.sol";

contract ZeroToken is IZeroToken, EpochBasedMintableVoteToken {
    constructor(
        address registrar_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) EpochBasedMintableVoteToken("Zero Token", "ZERO", 6, registrar_) {
        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert LengthMismatch(accountsLength_, balancesLength_);

        for (uint256 i = 0; i < accountsLength_; i++) {
            _mint(initialAccounts_[i], initialBalances_[i]);
        }
    }
}
