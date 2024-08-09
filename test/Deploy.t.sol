// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { DeployBase } from "../script/DeployBase.sol";

contract Deploy is Test, DeployBase {
    address internal _portal = makeAddr("portal");

    function test_deploy() external {
        address registrar_ = deploy(_portal);

        // Registrar assertions
        assertEq(registrar_, getExpectedRegistrar(address(this), 1));
        assertEq(IRegistrar(registrar_).portal(), _portal);
    }
}
