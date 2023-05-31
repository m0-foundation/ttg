// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";

contract SPOG_SellInactiveVoteInflation is Vault_IntegratedWithSPOG {
    function test_sellInactiveVoteInflation() public {
        uint256 initialBalance = governor.vote().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 adminBalance = vote.balanceOf(address(this));
        uint256 aliceBalance = vote.balanceOf(alice);
        uint256 bobBalance = vote.balanceOf(bob);
        uint256 carolBalance = vote.balanceOf(carol);

        assertEq(initialBalance, adminBalance + aliceBalance + bobBalance + carolBalance);

        // alice votes
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and carol do not vote

        // inflation should have happened
        uint256 inflatedBalance = governor.vote().totalSupply();

        uint256 totalInflation = inflatedBalance - initialBalance;

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation);

        // roll forward another epoch

        vm.roll(block.number + governor.votingPeriod() + 1);

        // anyone can call
        IVoteVault(voteVault).sellInactiveVoteInflation(governor.currentEpoch() - 1);

        // hard coded scenario uses half of voting weight
        uint256 inactiveCoinsInflation = totalInflation / 2;

        assertEq(governor.vote().balanceOf(address(voteVault)), totalInflation - inactiveCoinsInflation);
    }

    function test_sellInactiveVoteInflation_withFuzzBalances(uint256 daveBalance, uint256 ernieBalance) public {
        vm.assume(daveBalance > 0);
        vm.assume(ernieBalance > 0);

        vm.assume(daveBalance < 1_000_000_000_000e18); // less than a billion
        vm.assume(ernieBalance < 1_000_000_000_000e18); // less than a billion

        address dave = createUser("dave");
        address ernie = createUser("ernie");

        vote.mint(dave, daveBalance);
        vm.startPrank(dave);
        vote.delegate(dave);
        vm.stopPrank();

        vote.mint(ernie, ernieBalance);
        vm.startPrank(ernie);
        vote.delegate(ernie);
        vm.stopPrank();

        uint256 initialBalance = governor.vote().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 adminBalance = vote.balanceOf(address(this));
        uint256 aliceBalance = vote.balanceOf(alice);
        uint256 bobBalance = vote.balanceOf(bob);
        uint256 carolBalance = vote.balanceOf(carol);

        assertEq(initialBalance, adminBalance + aliceBalance + bobBalance + carolBalance + daveBalance + ernieBalance);

        // alice votes
        vm.startPrank(alice);
        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        governor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and carol do not vote

        // dave does not vote with fuzz balance

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

        // uint256 numProposals = governor.epochProposalsCount(governor.currentEpoch());
        // console.log("number of proposals: %s", numProposals);

        // console.log("Alice voted on", governor.accountEpochNumProposalsVotedOn(alice, epochs[0]), alice);
        // console.log("Bob voted on  ", governor.accountEpochNumProposalsVotedOn(bob, epochs[0]), bob);
        // console.log("Ernie voted on", governor.accountEpochNumProposalsVotedOn(ernie, epochs[0]), ernie);

        vm.startPrank(alice);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        vm.stopPrank();

        vm.startPrank(bob);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        vm.stopPrank();

        vm.startPrank(ernie);
        spog.voteVault().withdraw(epochs, address(governor.vote()));
        vm.stopPrank();

        // roll forward another epoch
        vm.roll(block.number + governor.votingPeriod() + 1);

        // anyone can call
        IVoteVault(voteVault).sellInactiveVoteInflation(epochs[0]);

        assertGe(governor.vote().balanceOf(address(voteVault)), 0);
    }
}
