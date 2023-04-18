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

    function setUp() public {
        ISPOGGovernor voteGovernorAddress = ISPOGGovernor(address(new MockSPOGGovernor()));
        ISPOGGovernor valueGovernorAddress = ISPOGGovernor(address(new MockSPOGGovernor()));
        vault = new Vault(voteGovernorAddress, valueGovernorAddress);

        // mint tokens to vault
        deal({token: address(dai), to: address(vault), give: 1000e18, adjust: true});
    }

    // NOTE: withdrawVoteTokenRewards() and withdrawValueTokenRewards() are tested in VoteGovernor.t.sol and ValueGovernor.t.sol
    // NOTE: sellERC20() is tested in spog/sellERC20/sellERC20.t.sol

    function test_admin() public {
        assertEq(vault.admin(), address(this));
    }

    function test_changeAdmin() public {
        assertEq(vault.admin(), address(this));

        address newAddress = createUser("somethingNew");
        vault.changeAdmin(newAddress);

        assertEq(vault.admin(), newAddress);
    }
}
