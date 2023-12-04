// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

interface IERC6372 {
    function CLOCK_MODE() external view returns (string memory clockMode);

    function clock() external view returns (uint48 clock);
}
