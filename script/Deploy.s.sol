// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { DeployBase } from "./DeployBase.sol";

contract Deploy is Script, DeployBase {
    // NOTE: Ensure this is the correct Portal testnet/mainnet address.
    address internal constant _PORTAL = 0x0000000000000000000000000000000000000000;

    function run() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        console2.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        address registrar_ = deploy(_PORTAL);

        vm.stopBroadcast();

        console2.log("Registrar Address:", registrar_);
    }
}
