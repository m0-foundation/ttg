// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { IControlledByComptroller } from "./IControlledByComptroller.sol";

abstract contract ControlledByComptroller is IControlledByComptroller {
    address public immutable comptroller;

    modifier onlyComptroller() {
        if (msg.sender != comptroller) revert CallerIsNotComptroller();

        _;
    }

    constructor(address comptroller_) {
        if (comptroller_ == address(0)) revert ZeroComptrollerAddress();

        comptroller = comptroller_;
    }
}
