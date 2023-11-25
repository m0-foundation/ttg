// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { DeployBase } from "./DeployBase.s.sol";

contract Deploy is DeployBase {
    uint16 internal constant _EMERGENCY_PROPOSAL_THRESHOLD_RATIO = 5_000; // 50%
    uint16 internal constant _ZERO_PROPOSAL_THRESHOLD_RATIO = 5_000; // 50%

    uint256 internal constant _STANDARD_PROPOSAL_FEE = 1e16; // 0.001 WETH

    // NOTE: Ensure these are the correct cash token addresses.
    address[] internal _ALLOWED_CASH_TOKENS = [
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) // mainnet WETH
    ];

    // NOTE: Ensure this is the current nonce (transaction count) of the deploying address.
    uint256 internal constant _DEPLOYER_NONCE = 0;

    // NOTE: Populate these arrays with accounts and starting balances.
    address[] _initialPowerAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialPowerBalances = [1_000_000];

    address[] _initialZeroAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialZeroBalances = [1_000_000];

    function run() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        deploy(
            deployer_,
            _DEPLOYER_NONCE,
            _initialZeroAccounts,
            _initialZeroBalances,
            _initialPowerAccounts,
            _initialPowerBalances,
            _ALLOWED_CASH_TOKENS,
            _STANDARD_PROPOSAL_FEE,
            _EMERGENCY_PROPOSAL_THRESHOLD_RATIO,
            _ZERO_PROPOSAL_THRESHOLD_RATIO
        );
    }
}
