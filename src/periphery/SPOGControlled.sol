// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ISPOGControlled } from "../interfaces/ISPOGControlled.sol";

abstract contract SPOGControlled is ISPOGControlled {
    address public immutable spog;

    modifier onlySPOG() {
        if (msg.sender != spog) revert CallerIsNotSPOG();

        _;
    }

    constructor(address spog_) {
        if (spog_ == address(0)) revert ZeroSPOGAddress();

        spog = spog_;
    }
}
