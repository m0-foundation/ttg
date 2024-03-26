// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { DeployBase } from "./DeployBase.sol";

contract Deploy is Script, DeployBase {
    uint256 internal constant _STANDARD_PROPOSAL_FEE = 1e18; // 1 WETH

    // NOTE: Populate this arrays with cash token addresses.
    address[] internal _ALLOWED_CASH_TOKENS = [
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) // mainnet WETH
    ];

    // NOTE: Populate these arrays with Power ad Zero starting accounts respectively.
    address[][2] _initialAccounts = [
        [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)],
        [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)]
    ];

    // NOTE: Populate these arrays with Power ad Zero starting balances respectively.
    uint256[][2] _initialBalances = [[uint256(10_000)], [uint256(1_000_000_000e6)]];

    function run() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        console2.log("deployer: ", deployer_);

        vm.startBroadcast(deployer_);

        address registrar_ = deploy(
            deployer_,
            vm.getNonce(deployer_),
            _initialAccounts,
            _initialBalances,
            _STANDARD_PROPOSAL_FEE,
            _ALLOWED_CASH_TOKENS
        );

        vm.stopBroadcast();

        console2.log("Registrar Address:", registrar_);
        console2.log("Power Token Address:", IRegistrar(registrar_).powerToken());
        console2.log("Zero Token Address:", IRegistrar(registrar_).zeroToken());
        console2.log("Standard Governor Address:", IRegistrar(registrar_).standardGovernor());
        console2.log("Emergency Governor Address:", IRegistrar(registrar_).emergencyGovernor());
        console2.log("Zero Governor Address:", IRegistrar(registrar_).zeroGovernor());
        console2.log("Distribution Vault Address:", IRegistrar(registrar_).vault());
    }
}
