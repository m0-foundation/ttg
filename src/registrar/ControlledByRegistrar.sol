// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IControlledByRegistrar } from "./IControlledByRegistrar.sol";

abstract contract ControlledByRegistrar is IControlledByRegistrar {
    address public immutable registrar;

    modifier onlyRegistrar() {
        if (msg.sender != registrar) revert CallerIsNotRegistrar();

        _;
    }

    constructor(address registrar_) {
        if (registrar_ == address(0)) revert ZeroRegistrarAddress();

        registrar = registrar_;
    }
}
