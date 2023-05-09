// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {SPOGVotes} from "src/tokens/SPOGVotes.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract TestSpogVotes is SPOG_Base {
    function test_MintAndBurn() public {
        SPOGVotes spogVotes = new SPOGVotes("SPOGVotes", "SPOGVotes");
        // grant minter role to this contract
        IAccessControl(address(spogVotes)).grantRole(spogVotes.MINTER_ROLE(), address(this));

        address user = createUser("user");

        // test mint
        spogVotes.mint(user, 100);

        assertEq(spogVotes.balanceOf(user), 100);

        // test burn
        vm.prank(user);
        spogVotes.burn(50);

        assertEq(spogVotes.balanceOf(user), 50);

        // test burnFrom
        address user2 = createUser("user2");

        vm.prank(user);
        spogVotes.approve(user2, 25);

        vm.prank(user2);
        spogVotes.burnFrom(user, 25);

        assertEq(spogVotes.balanceOf(user), 25);
    }
}
