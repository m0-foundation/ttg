// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract TestSpogVotes is SPOG_Base {
    function test_MintAndBurn() public {
        SPOGVotes spogVotes = new SPOGVotes("SPOGVotes", "SPOGVotes");
        // grant minter role to this contract
        IAccessControl(address(spogVotes)).grantRole(spogVotes.MINTER_ROLE(), address(this));

        address user = createUser("user");

        // test mint
        spogVotes.mint(user, 100);

        assertEq(spogVotes.balanceOf(user), 100);
    }
}
