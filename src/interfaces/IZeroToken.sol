// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEpochBasedVoteToken } from "./IEpochBasedVoteToken.sol";

interface IZeroToken is IEpochBasedVoteToken {
    error LengthMismatch(uint256 length1, uint256 length2);

    error NotGovernor();

    function mint(address recipient, uint256 amount) external;

    function registrar() external view returns (address registrar);
}
