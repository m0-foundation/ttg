// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IEpochBasedVoteToken } from "./IEpochBasedVoteToken.sol";

interface IEpochBasedMintableVoteToken is IEpochBasedVoteToken {
    error NotGovernor();

    function mint(address recipient, uint256 amount) external;

    function registrar() external view returns (address registrar);
}
