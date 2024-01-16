// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ContractHelper } from "../lib/common/src/ContractHelper.sol";

import { DeployBase } from "./DeployBase.s.sol";

contract Deploy is DeployBase {
    uint256 internal constant _STANDARD_PROPOSAL_FEE = 1e18; // 1 WETH

    // NOTE: Populate these arrays with accounts and starting balances.
    address[] _initialPowerAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialPowerBalances = [10_000];

    address[] _initialZeroAccounts = [address(0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD)];

    uint256[] _initialZeroBalances = [1_000_000_000e6];

    function run() external {
        (address deployer_, ) = deriveRememberKey(vm.envString("MNEMONIC"), 0);

        // NOTE: Ensure this is the current nonce (transaction count) of the deploying address.
        uint256 deployerNonce_ = vm.envUint("DEPLOYER_NONCE");

        address[] memory allowedCashTokens_ = new address[](2);

        // NOTE: Ensure these are the correct cash token addresses.
        allowedCashTokens_[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // mainnet WETH
        allowedCashTokens_[1] = ContractHelper.getContractFrom(deployer_, deployerNonce_ + 8); // M token address

        deploy(
            deployer_,
            _initialPowerAccounts,
            _initialPowerBalances,
            _initialZeroAccounts,
            _initialZeroBalances,
            _STANDARD_PROPOSAL_FEE,
            allowedCashTokens_
        );
    }
}
