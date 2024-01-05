// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DeployBase } from "./DeployBase.s.sol";

contract Deploy is DeployBase {
    uint256 internal constant _STANDARD_PROPOSAL_FEE = 1e18; // 1 WETH

    // NOTE: Ensure these are the correct cash token addresses.
    address[] internal _ALLOWED_CASH_TOKENS = [
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) // mainnet WETH
    ];

    // NOTE: Populate these arrays with accounts and starting balances.
    address[] _initialPowerAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialPowerBalances = [10_000];

    address[] _initialZeroAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialZeroBalances = [1_000_000_000e6];

    function run() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        deploy(
            deployer_,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _STANDARD_PROPOSAL_FEE,
            _ALLOWED_CASH_TOKENS
        );
    }
}
