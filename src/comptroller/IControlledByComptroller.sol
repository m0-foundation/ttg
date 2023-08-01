// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IControlledByComptroller {
    // Errors
    error CallerIsNotComptroller();
    error ZeroComptrollerAddress();

    function comptroller() external view returns (address comptroller);
}
