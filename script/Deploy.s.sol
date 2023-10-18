// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { DeployBase } from "./DeployBase.s.sol";

contract Deploy is DeployBase {
    uint256 internal constant _STANDARD_PROPOSAL_FEE = 1e16; // 0.001 WETH

    // NOTE: Ensure these are the correct cash token addresses.
    address[] internal _ALLOWED_CASH_TOKENS = [
        address(0xE67ABDA0D43f7AC8f37876bBF00D1DFadbB93aaa), // WETH
        address(0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8) // USDC
    ];

    // NOTE: Populate these arrays with accounts and starting balances.
    address[] _initialPowerAccounts = [
        address(0xB609BD6dA626F6bb2096DFdd99E0DA060f76C40D), // luis
        address(0xbCcA4494d525008f70Ba72Ac8D1A57B4D1908FcF), // Antonina
        address(0x92338d620DA206dCB3cF3384103f419b21114c2A), // Sebastian
        address(0x7D6105D75C5E6A40791a50a52a92365545e9B112), // Greg
        address(0x3Bc2781df4469b324BBc3b683f22039d6a326121), // Rafael
        address(0x1776B8cc63ab151aa6334f725D8cb4155dC957bA), // oliver
        address(0x942AeF058cb15C9b8b89B57B4E607d464ed8Cd33), // Conrado
        address(0x895987beB35b1C289c116C876e915550e0d12628), // Andrei
        address(0x3A791e828fDd420fbE16416efDF509E4b9088Dd4) // Pierrick
    ];

    uint256[] _initialPowerBalances = [
        200_000_000,
        100_000_000,
        100_000_000,
        100_000_000,
        100_000_000,
        100_000_000,
        100_000_000,
        100_000_000,
        100_000_000
    ];

    address[] _initialZeroAccounts = _initialPowerAccounts;

    uint256[] _initialZeroBalances = _initialPowerBalances;

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
