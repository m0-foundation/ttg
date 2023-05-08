// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "test/vault/helper/Vault_IntegratedWithSPOG.t.sol";

contract Vault_WithdrawRewardsForValueHolders is Vault_IntegratedWithSPOG {
    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // calculate value token inflation rewards for voter
    function createProposalsForEpochs(uint256 numberOfEpochs, uint256 numberOfProposalsPerEpoch) private {
        for (uint256 i = 0; i < numberOfEpochs; i++) {
            // advance to next epoch
            vm.roll(block.number + voteGovernor.votingDelay() + 1);

            for (uint256 j = 0; j < numberOfProposalsPerEpoch; j++) {
                // update vote governor
                string memory proposalDescription =
                    string(abi.encodePacked("Add new list to spog: epochNumber, proposalNumberPerEpoch", i, j));
                proposeAddingNewListToSpog(proposalDescription);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawRewardsForValueHolders_For_Single_Epoch() public {
        // initially Vault has 0 balance of Cash value
        uint256 initialVaultBalanceOfCash = cash.balanceOf(address(valueVault));
        assertEq(initialVaultBalanceOfCash, 0, "Vault should have 0 balance of Cash value");

        // set up proposals for 1 epoch with 2 proposals
        uint256 numberOfEpochs = 1;
        uint256 numberOfProposalsPerEpoch = 2;
        createProposalsForEpochs(numberOfEpochs, numberOfProposalsPerEpoch);

        uint256 vaultBalanceOfCash = cash.balanceOf(address(valueVault));
        // get spog tax from spog data
        (uint256 tax,,) = spog.spogData();

        uint256 epochCashRewards = tax * numberOfProposalsPerEpoch * numberOfEpochs;
        assertEq(vaultBalanceOfCash, epochCashRewards, "Vault should have balance of Cash value");

        // another sanity check
        uint256 epochToGetRewardsFor = 1;
        uint256 epochCashRewardDepositInVault = valueVault.epochTokenDeposit(address(cash), epochToGetRewardsFor);
        assertEq(
            epochCashRewardDepositInVault,
            epochCashRewards,
            "Vault's epochCashRewardDepositInVault should be equal to epochCashRewards"
        );

        // advance to next epoch so msg.sender can take rewards from previous epoch
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        // rewards is divvied up equally among value holders (alice, bob, carol, and address(this))
        uint256 rewardAmountToReceive = epochCashRewards / 4;

        // first value holder withdraws rewards
        uint256 initialBalanceOfCash = cash.balanceOf(address(this));

        valueVault.withdrawRewards(epochToGetRewardsFor, address(cash));

        uint256 finalBalanceOfCash = cash.balanceOf(address(this));
        assertEq(
            finalBalanceOfCash, initialBalanceOfCash + rewardAmountToReceive, "Vault should have balance of Cash value"
        );

        // second value holder withdraws rewards
        vm.startPrank(alice);
        uint256 initialAliceBalanceOfCash = cash.balanceOf(address(alice));

        valueVault.withdrawRewards(epochToGetRewardsFor, address(cash));

        uint256 finalAliceBalanceOfCash = cash.balanceOf(address(alice));
        assertEq(
            finalAliceBalanceOfCash,
            initialAliceBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );
        vm.stopPrank();

        // third value holder withdraws rewards
        vm.startPrank(bob);
        uint256 initialBobBalanceOfCash = cash.balanceOf(address(bob));

        valueVault.withdrawRewards(epochToGetRewardsFor, address(cash));

        uint256 finalBobBalanceOfCash = cash.balanceOf(address(bob));
        assertEq(
            finalBobBalanceOfCash,
            initialBobBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );
        vm.stopPrank();

        // last value holder withdraws rewards
        vm.startPrank(carol);
        uint256 initialCarolBalanceOfCash = cash.balanceOf(address(carol));

        valueVault.withdrawRewards(epochToGetRewardsFor, address(cash));

        uint256 finalCarolBalanceOfCash = cash.balanceOf(address(carol));
        assertEq(
            finalCarolBalanceOfCash,
            initialCarolBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );
        vm.stopPrank();
    }
}
