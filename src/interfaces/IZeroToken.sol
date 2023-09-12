// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IEpochBasedMintableVoteToken } from "./IEpochBasedMintableVoteToken.sol";

interface IZeroToken is IEpochBasedMintableVoteToken {
    error LengthMismatch(uint256 length1, uint256 length2);
}
