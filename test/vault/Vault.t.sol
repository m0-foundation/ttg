// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {StdCheats} from "forge-std/StdCheats.sol";
import {Vault} from "src/periphery/Vault.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {BaseTest} from "test/Base.t.sol";

contract MockSPOGGovernor is StdCheats {
    address public immutable spogAddress;

    constructor() {
        spogAddress = makeAddr("spog");
    }
}

contract VaultTest is BaseTest {
    Vault public vault;

    // Event to test
    event Withdraw(address indexed account, address token, uint256 amount);
    event VoteTokenRewardsWithdrawn(address indexed account, address token, uint256 amount);

    function setUp() public {
        ISPOGGovernor govSpogVoteAddress = ISPOGGovernor(address(new MockSPOGGovernor()));
        ISPOGGovernor govSpogValueAddress = ISPOGGovernor(address(new MockSPOGGovernor()));
        vault = new Vault(govSpogVoteAddress, govSpogValueAddress);

        // mint tokens to vault
        deal({token: address(dai), to: address(vault), give: 1000e18, adjust: true});
    }
}
