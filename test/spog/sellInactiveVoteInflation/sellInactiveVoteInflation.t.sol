// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";
import {ValueToken} from "src/tokens/ValueToken.sol";
import {VoteToken} from "src/tokens/VoteToken.sol";

contract SPOG_SellInactiveVoteInflation is Vault_IntegratedWithSPOG {
    function test_sellUnclaimedVoteTokens() public {
        setUp();

        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // deposit rewards for previous epoch
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        vm.startPrank(alice);
        voteGovernor.castVote(proposalId, yesVote);
        vm.stopPrank();

        vm.startPrank(bob);
        voteGovernor.castVote(proposalId, noVote);
        vm.stopPrank();

        vm.roll(block.number + voteGovernor.votingPeriod() + 1);

        assertEq(voteGovernor.votingToken().balanceOf(address(voteVault)), 20000000000000000000);

        // anyone can call
        spog.sellInactiveVoteInflation(voteGovernor.currentEpoch() - 1);

        assertEq(voteGovernor.votingToken().balanceOf(address(voteVault)), 11200000000000000000);
    }
}
