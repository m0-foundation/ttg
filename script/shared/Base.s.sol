// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant _TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev The address of the contract deployer.
    address internal _deployer;

    /// @dev Used to derive the deployer's address.
    string internal _mnemonic;

    constructor() {
        _mnemonic = vm.envOr("MNEMONIC", _TEST_MNEMONIC);
        (_deployer,) = deriveRememberKey({mnemonic: _mnemonic, index: 0});
    }

    modifier broadcaster() {
        vm.startBroadcast(_deployer);
        _;
        vm.stopBroadcast();
    }
}
