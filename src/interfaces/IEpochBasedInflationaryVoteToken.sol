// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEpochBasedVoteToken } from "./IEpochBasedVoteToken.sol";

interface IEpochBasedInflationaryVoteToken is IEpochBasedVoteToken {
    error AlreadyParticipated();

    error NotVoteEpoch();

    error VoteEpoch();

    function hasParticipatedAt(address delegatee, uint256 epoch) external view returns (bool participated);

    function participationInflation() external view returns (uint256 participationInflation);

    function ONE() external pure returns (uint256 one);
}
