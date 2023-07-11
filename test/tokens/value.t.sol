// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISPOGControlled } from "../../src/interfaces/ISPOGControlled.sol";

import { VALUE } from "../../src/tokens/VALUE.sol";

import { IAccessControl } from "../interfaces/ImportedInterfaces.sol";

import { ERC20Snapshot } from "../ImportedContracts.sol";
import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract ValueTokenTest is SPOGBaseTest {

    uint256 aliceStartBalance = 50e18;

    VALUE valueToken;

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();

        valueToken = new VALUE("SPOGValue", "value");
        valueToken.initializeSPOG(address(spog));

        // grant mint role to this contract
        IAccessControl(address(valueToken)).grantRole(valueToken.MINTER_ROLE(), address(this));

        // Alice can interact with blockchain
        vm.deal({account: alice, newBalance: 10 ether});
    }

    function test_Revert_Snapshot_WhenCallerIsNotSPOG() public {
        vm.expectRevert(ISPOGControlled.CallerIsNotSPOG.selector);
        valueToken.snapshot();
    }

    function test_snapshot() public {
        // Mint initial balance for alice
        valueToken.mint(alice, aliceStartBalance);
        assertEq(valueToken.balanceOf(alice), aliceStartBalance);

        // SPOG takes snapshot
        vm.startPrank(address(spog));
        uint256 snapshotId = valueToken.snapshot();

        uint256 aliceSnapshotBalance = ERC20Snapshot(valueToken).balanceOfAt(address(alice), snapshotId);
        assertEq(aliceSnapshotBalance, aliceStartBalance, "Alice snapshot balance is incorrect");
    }

    function test_MintAndBurn() public {
        address user = createUser("user");

        // test mint
        valueToken.mint(user, 100);

        assertEq(valueToken.balanceOf(user), 100);
    }

}
