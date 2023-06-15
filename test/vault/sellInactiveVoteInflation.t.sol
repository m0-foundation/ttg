// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_SellInactiveVoteInflation is SPOG_Base {
    function test_sellInactiveVoteInflation() public {
        uint256 initialBalance = governor.vote().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 adminBalance = vote.balanceOf(admin);
        uint256 aliceBalance = vote.balanceOf(alice);
        uint256 bobBalance = vote.balanceOf(bob);
        uint256 charlieBalance = vote.balanceOf(charlie);
        uint256 daveBalance = vote.balanceOf(dave);

        uint256 userBalances = adminBalance + aliceBalance + bobBalance + charlieBalance + daveBalance;

        console.log("balances", initialBalance, userBalances);

        assertEq(initialBalance, userBalances);

        // alice votes
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        // charlie votes
        vm.startPrank(charlie);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and dave do not vote

        // inflation should have happened
        uint256 inflatedBalance = governor.vote().totalSupply();

        uint256 totalInflation = inflatedBalance - initialBalance;

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation);

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = governor.currentEpoch();

        // roll forward another epoch
        vm.roll(block.number + governor.votingPeriod() + 1);

        // anyone can call
        voteVault.sellInactiveVoteInflation(epochs);

        // scenario uses 3/5 voting weight
        uint256 inactiveCoinsInflation = totalInflation / 5 * 2;

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation - inactiveCoinsInflation);
    }

    function test_Revert_sellInactiveVoteInflation_whenEpochAlreadyAuctioned() public {
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = governor.currentEpoch();

        // roll forward another epoch
        vm.roll(block.number + governor.votingPeriod() + 1);

        // anyone can call
        (address auctionAddress,) = voteVault.sellInactiveVoteInflation(epochs);

        vm.expectRevert(abi.encodeWithSelector(IVoteVault.AuctionAlreadyExists.selector, epochs[0], auctionAddress));

        //attempt to auction same epoch again
        voteVault.sellInactiveVoteInflation(epochs);
    }

    function test_sellInactiveVoteInflation_withFuzzBalances(uint256 ernieBalance) public {
        vm.assume(ernieBalance > 0);

        vm.assume(ernieBalance < 1_000_000_000_000e18); // less than a billion

        address ernie = createUser("ernie");

        vm.prank(address(spog));
        vote.mint(ernie, ernieBalance);
        vm.startPrank(ernie);
        vote.delegate(ernie);
        vm.stopPrank();

        uint256 initialBalance = governor.vote().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 adminBalance = vote.balanceOf(admin);
        uint256 aliceBalance = vote.balanceOf(alice);
        uint256 bobBalance = vote.balanceOf(bob);
        uint256 charlieBalance = vote.balanceOf(charlie);
        uint256 daveBalance = vote.balanceOf(dave);

        assertEq(initialBalance, adminBalance + aliceBalance + bobBalance + charlieBalance + daveBalance + ernieBalance);

        // alice votes
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and charlie do not vote

        // ernie votes with fuzz balance
        vm.startPrank(ernie);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // inflation should have happened
        uint256 inflatedBalance = governor.vote().totalSupply();

        uint256 totalInflation = inflatedBalance - initialBalance;

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation);

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = governor.currentEpoch();

        uint256 activeInflatedAmount;

        vm.startPrank(alice);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        activeInflatedAmount += governor.vote().balanceOf(alice) - aliceBalance;
        vm.stopPrank();

        vm.startPrank(bob);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        activeInflatedAmount += governor.vote().balanceOf(bob) - bobBalance;
        vm.stopPrank();

        vm.startPrank(ernie);
        uint256 ernieBefore = governor.vote().balanceOf(ernie);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        activeInflatedAmount += governor.vote().balanceOf(ernie) - ernieBefore;
        vm.stopPrank();

        // roll forward another epoch
        vm.roll(block.number + governor.votingPeriod() + 1);

        // anyone can call
        (, uint256 amountToSell) = voteVault.sellInactiveVoteInflation(epochs);

        // Assert that the amount to sell is never more than amount that can be claimed
        // Note - this does leave small dust amounts in the vault due to rounding
        assertLe(amountToSell, totalInflation - activeInflatedAmount);

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation - activeInflatedAmount - amountToSell);
    }
}
