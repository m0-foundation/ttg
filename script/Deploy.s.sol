// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { IDualGovernor } from "../src/interfaces/IDualGovernor.sol";
import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { ContractHelper } from "../src/ContractHelper.sol";
import { DualGovernorDeployer } from "../src/DualGovernorDeployer.sol";
import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";
import { PowerTokenDeployer } from "../src/PowerTokenDeployer.sol";
import { Registrar } from "../src/Registrar.sol";
import { ZeroToken } from "../src/ZeroToken.sol";

contract Deploy is Script {
    uint256 internal constant _DEPLOYER_STARTING_NONCE = 0;

    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address internal _deployer;

    function setUp() external {
        string memory mnemonic = vm.envString("MNEMONIC");

        (_deployer, ) = deriveRememberKey(mnemonic, 0);

        console.log("deployer: %s", _deployer);
    }

    function run(
        address[] memory initialPowerAccounts_,
        uint256[] memory initialPowerBalances_,
        address[] memory initialZeroAccounts_,
        uint256[] memory initialZeroBalances_,
        address cashToken_
    ) external returns (address registrar_) {
        vm.startBroadcast(_deployer);

        // ZeroToken needs registrar address.
        // DualGovernorDeployer needs registrar and zeroToken address.
        // PowerTokenDeployer needs registrar and treasury.
        // Registrar needs governorDeployer, powerTokenDeployer, bootstrapToken, and cashToken address.
        // PowerBootstrapToken needs nothing.

        address expectedRegistrar_ = ContractHelper.getContractFrom(_deployer, _DEPLOYER_STARTING_NONCE + 4);

        address zeroToken_ = address(new ZeroToken(expectedRegistrar_, initialZeroAccounts_, initialZeroBalances_));
        address governorDeployer_ = address(new DualGovernorDeployer(expectedRegistrar_, zeroToken_));
        address powerTokenDeployer_ = address(new PowerTokenDeployer(expectedRegistrar_, _deployer)); // `_treasury`
        address bootstrapToken_ = address(new PowerBootstrapToken(initialPowerAccounts_, initialPowerBalances_));

        registrar_ = address(new Registrar(governorDeployer_, powerTokenDeployer_, bootstrapToken_, cashToken_));

        address governor_ = IRegistrar(registrar_).governor();

        console.log("Zero Token Address: ", zeroToken_);
        console.log("Registrar address: ", registrar_);
        console.log("DualGovernor Address: ", governor_);
        console.log("Power Token Address: ", IDualGovernor(governor_).powerToken());

        vm.stopBroadcast();
    }
}
