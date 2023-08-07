// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IControlledByRegistrar {
    // Errors
    error CallerIsNotRegistrar();
    error ZeroRegistrarAddress();

    function registrar() external view returns (address registrar);
}
