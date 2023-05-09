// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {BaseScript} from "script/shared/Base.s.sol";
import {SPOGDeployScript} from "script/SPOGDeploy.s.sol";
import {console} from "forge-std/Script.sol";

contract LocalTestDeployScript is BaseScript {
    SPOGDeployScript public spogDeployScript;

    function setUp() public override {
        super.setUp();

        // deploy SPOG
        spogDeployScript = new SPOGDeployScript();
        spogDeployScript.run();
    }

    function run() public {
        vm.startBroadcast(deployer);
        // set up users
        string memory mnemonic = vm.envString("MNEMONIC");
        // string memory mnemonic = "test test test test test test test test test test test junk"; // anvil accounts mnemonic
        (address user1,) = deriveRememberKey(mnemonic, 1);
        (address user2,) = deriveRememberKey(mnemonic, 2);
        // (address user3,) = deriveRememberKey(mnemonic, 3);
        // (address user4,) = deriveRememberKey(mnemonic, 4);
        // (address user5,) = deriveRememberKey(mnemonic, 5);

        address[2] memory users = [user1, user2];
        // mint tokens to users
        uint256 amount = 100000e18; // 100K

        for (uint256 i = 0; i < users.length; i++) {
            spogDeployScript.cash().mint(users[i], amount);
            spogDeployScript.value().mint(users[i], amount);
            spogDeployScript.vote().mint(users[i], amount);
        }

        console.log("Minted 100K cash, value, and vote to each user");

        vm.stopBroadcast();
    }
}
