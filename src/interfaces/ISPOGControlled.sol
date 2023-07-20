// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISPOGControlled {
    // Errors
    error CallerIsNotSPOG();
    error ZeroSPOGAddress();

    function spog() external view returns (address spog);
}
