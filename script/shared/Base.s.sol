// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    address public deployer;

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC"); // USE ENV VAR FOR PRODUCTION

        (deployer,) = deriveRememberKey(mnemonic, 0);

        console.log("deployer: %s", deployer);
    }
}
