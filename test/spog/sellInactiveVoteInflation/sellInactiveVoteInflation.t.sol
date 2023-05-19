// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";

contract SPOG_SellInactiveVoteInflation is Vault_IntegratedWithSPOG {
    function test_sellInactiveVoteInflation() public {
        uint256 initialBalance = voteGovernor.votingToken().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 adminBalance = spogVote.balanceOf(address(this));
        uint256 aliceBalance = spogVote.balanceOf(alice);
        uint256 bobBalance = spogVote.balanceOf(bob);
        uint256 carolBalance = spogVote.balanceOf(carol);

        assertEq(initialBalance, adminBalance + aliceBalance + bobBalance + carolBalance);

        // alice votes
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        voteGovernor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and carol do not vote

        // inflation should have happened
        uint256 inflatedBalance = voteGovernor.votingToken().totalSupply();

        uint256 totalInflation = inflatedBalance - initialBalance;

        assertEq(voteGovernor.votingToken().balanceOf(address(voteVault)), totalInflation);

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = voteGovernor.currentEpoch();

        // roll forward another epoch
        vm.roll(block.number + voteGovernor.votingPeriod() + 1);

        // anyone can call
        spog.sellInactiveVoteInflation(epochs);

        // hard coded scenario uses half of voting weight
        uint256 inactiveCoinsInflation = totalInflation / 2;

        assertEq(voteGovernor.votingToken().balanceOf(address(voteVault)), totalInflation - inactiveCoinsInflation);
    }

    function test_sellInactiveVoteInflation_withFuzzBalances(uint256 daveBalance, uint256 ernieBalance) public {
        vm.assume(daveBalance > 0);
        vm.assume(ernieBalance > 0);

        vm.assume(daveBalance < 1_000_000_000_000e18); // less than a billion
        vm.assume(ernieBalance < 1_000_000_000_000e18); // less than a billion

        address dave = createUser("dave");
        address ernie = createUser("ernie");

        spogVote.mint(dave, daveBalance);
        vm.startPrank(dave);
        spogVote.delegate(dave);
        vm.stopPrank();

        spogVote.mint(ernie, ernieBalance);
        vm.startPrank(ernie);
        spogVote.delegate(ernie);
        vm.stopPrank();

        uint256 initialBalance = voteGovernor.votingToken().totalSupply();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 adminBalance = spogVote.balanceOf(address(this));
        uint256 aliceBalance = spogVote.balanceOf(alice);
        uint256 bobBalance = spogVote.balanceOf(bob);
        uint256 carolBalance = spogVote.balanceOf(carol);

        assertEq(initialBalance, adminBalance + aliceBalance + bobBalance + carolBalance + daveBalance + ernieBalance);

        // alice votes
        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // bob votes
        vm.startPrank(bob);
        voteGovernor.castVote(proposalId, noVote);
        vm.stopPrank();

        //admin and carol do not vote

        // dave does not vote with fuzz balance

        // ernie votes with fuzz balance
        vm.startPrank(ernie);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        // inflation should have happened
        uint256 inflatedBalance = voteGovernor.votingToken().totalSupply();

        uint256 totalInflation = inflatedBalance - initialBalance;

        assertEq(voteGovernor.votingToken().balanceOf(address(voteVault)), totalInflation);

        uint256[] memory epochs = new uint256[](1);
        epochs[0] = voteGovernor.currentEpoch();

        uint256 activeInflatedAmount;

        vm.startPrank(alice);
        spog.voteVault().claimRewards(epochs, address(voteGovernor.votingToken()));
        activeInflatedAmount += voteGovernor.votingToken().balanceOf(alice) - aliceBalance;
        vm.stopPrank();

        vm.startPrank(bob);
        spog.voteVault().claimRewards(epochs, address(voteGovernor.votingToken()));
        activeInflatedAmount += voteGovernor.votingToken().balanceOf(bob) - bobBalance;
        vm.stopPrank();

        vm.startPrank(ernie);
        uint256 ernieBefore = voteGovernor.votingToken().balanceOf(ernie);
        spog.voteVault().claimRewards(epochs, address(voteGovernor.votingToken()));
        activeInflatedAmount += voteGovernor.votingToken().balanceOf(ernie) - ernieBefore;
        vm.stopPrank();

        // roll forward another epoch
        vm.roll(block.number + voteGovernor.votingPeriod() + 1);

        // anyone can call
        (, uint256 amountToSell) = spog.sellInactiveVoteInflation(epochs);

        // Assert that the amount to sell is never more than amount that can be claimed
        // Note - this does leave small dust amounts in the vault due to rounding
        assertLe(amountToSell, totalInflation - activeInflatedAmount);

        assertEq(
            voteGovernor.votingToken().balanceOf(address(voteVault)),
            totalInflation - activeInflatedAmount - amountToSell
        );
    }
}
