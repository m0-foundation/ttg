// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    address internal deployer;

    function setUp() public virtual {
        deployer = msg.sender;

        // if using mnemonic, this is how it can be set up
        // string mnemonic = vm.envString("MNEMONIC");
        // (deployer, ) = deriveRememberKey(mnemonic, 0);
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}
