// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { DeployBase } from "./DeployBase.s.sol";

contract Deploy is DeployBase {
    address internal constant _WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    uint256 internal constant _DEPLOYER_NONCE = 0;

    address[] _initialPowerAccounts;

    uint256[] _initialPowerBalances;

    address[] _initialZeroAccounts;

    uint256[] _initialZeroBalances;

    function deploy() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        deploy(
            deployer_,
            _DEPLOYER_NONCE,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _WETH
        );
    }
}
