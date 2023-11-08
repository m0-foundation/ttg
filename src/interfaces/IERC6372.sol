// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

interface IERC6372 {
    function clock() external view returns (uint48 clock);

    function CLOCK_MODE() external view returns (string memory clockMode);
}
