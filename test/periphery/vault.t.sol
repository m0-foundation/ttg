// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract VaultTest is SPOGBaseTest {
    event EpochAssetsDeposited(uint256 indexed epoch, address indexed token, uint256 amount);

    /******************************************************************************************************************/
    /*** HELPERS                                                                                                    ***/
    /******************************************************************************************************************/

    // calculate value token inflation rewards for voter
    function createProposalsForEpochs(
        uint256 numberOfEpochs,
        uint256 numberOfProposalsPerEpoch
    ) internal returns (uint256[] memory epochs) {
        epochs = new uint256[](numberOfEpochs);

        for (uint256 i = 0; i < numberOfEpochs; i++) {
            // advance to next epoch
            // TODO: Remove `+ 1` once we get rid of OZ contracts and implement correct state and votingDelay functions.
            vm.roll(block.number + governor.votingDelay() + 1);

            epochs[i] = governor.currentEpoch();

            for (uint256 j = 0; j < numberOfProposalsPerEpoch; j++) {
                // update vote governor
                proposeAddingAnAddressToList(makeAddr(string(abi.encode("Account-i", i, "-j-", j))));
            }
        }
    }

    /******************************************************************************************************************/
    /*** TESTS                                                                                                      ***/
    /******************************************************************************************************************/

    function test_ClaimRewardsByValueHolders_For_Single_Epoch() public {
        // initially Vault has 0 balance of Cash value
        uint256 initialVaultBalanceOfCash = cash.balanceOf(address(vault));
        assertEq(initialVaultBalanceOfCash, 0, "Vault should have 0 balance of Cash value");

        // set up proposals for 1 epoch with 2 proposals
        uint256 numberOfEpochs = 1;
        uint256 numberOfProposalsPerEpoch = 2;
        uint256[] memory epochs = createProposalsForEpochs(numberOfEpochs, numberOfProposalsPerEpoch);

        uint256 vaultBalanceOfCash = cash.balanceOf(address(vault));
        // get spog tax from spog data
        uint256 tax = spog.tax();

        uint256 epochCashRewards = tax * numberOfProposalsPerEpoch * numberOfEpochs;
        assertEq(vaultBalanceOfCash, epochCashRewards, "Vault should have balance of Cash value");

        uint256[] memory epochsToGetRewardsFor = new uint256[](1);
        epochsToGetRewardsFor[0] = epochs[0];

        // TODO: use vault interface
        uint256 epochCashRewardDepositInVault = vault.deposits(epochs[0], address(cash));

        assertEq(
            epochCashRewardDepositInVault,
            epochCashRewards,
            "Vault's epochCashRewardDepositInVault should be equal to epochCashRewards"
        );

        // advance to next epoch so msg.sender can withdraw assets from previous epoch
        vm.roll(block.number + governor.votingDelay() + 1);

        // assets are dividied up equally among value holders (alice, bob, carol, and address(this))
        uint256 rewardAmountToReceive = epochCashRewards / 4;

        // first value holder withdraws assets
        uint256 initialBalanceOfCash = cash.balanceOf(address(this));

        vault.withdraw(epochsToGetRewardsFor, address(cash));

        uint256 finalBalanceOfCash = cash.balanceOf(address(this));

        assertEq(
            finalBalanceOfCash,
            initialBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );

        // second value holder withdraws assets
        vm.startPrank(alice);
        uint256 initialAliceBalanceOfCash = cash.balanceOf(address(alice));

        vault.withdraw(epochsToGetRewardsFor, address(cash));

        uint256 finalAliceBalanceOfCash = cash.balanceOf(address(alice));

        assertEq(
            finalAliceBalanceOfCash,
            initialAliceBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );

        vm.stopPrank();

        // third value holder withdraws assets
        vm.startPrank(bob);
        uint256 initialBobBalanceOfCash = cash.balanceOf(address(bob));

        vault.withdraw(epochsToGetRewardsFor, address(cash));

        uint256 finalBobBalanceOfCash = cash.balanceOf(address(bob));

        assertEq(
            finalBobBalanceOfCash,
            initialBobBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );

        vm.stopPrank();

        // last value holder withdraws assets
        vm.startPrank(carol);
        uint256 initialCarolBalanceOfCash = cash.balanceOf(address(carol));

        vault.withdraw(epochsToGetRewardsFor, address(cash));

        uint256 finalCarolBalanceOfCash = cash.balanceOf(address(carol));

        assertEq(
            finalCarolBalanceOfCash,
            initialCarolBalanceOfCash + rewardAmountToReceive,
            "Vault should have balance of Cash value"
        );

        vm.stopPrank();
    }

    function test_ClaimRewardsByValueHolders_For_Various_Epoch() public {
        // initially Vault has 0 balance of Cash value
        uint256 initialVaultBalanceOfCash = cash.balanceOf(address(vault));
        assertEq(initialVaultBalanceOfCash, 0, "Vault should have 0 balance of Cash value");

        // set up proposals for 3 epochs with 2 proposals
        uint256 numberOfEpochs = 3;
        uint256 numberOfProposalsPerEpoch = 2;
        uint256[] memory epochs = createProposalsForEpochs(numberOfEpochs, numberOfProposalsPerEpoch);

        uint256 vaultBalanceOfCash = cash.balanceOf(address(vault));
        // get spog tax from spog data
        uint256 tax = spog.tax();

        uint256 epochCashRewards = tax * numberOfProposalsPerEpoch * numberOfEpochs;

        assertEq(vaultBalanceOfCash, epochCashRewards, "Vault should have balance of Cash value");

        uint256 epochCashRewardDepositInVault = vault.deposits(epochs[0], address(cash)) * numberOfEpochs;

        assertEq(
            epochCashRewardDepositInVault,
            epochCashRewards,
            "Vault's epochCashRewardDepositInVault should be equal to epochCashRewards"
        );

        // advance to next epoch so msg.sender can withdraw assets
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 initialBalanceOfCash = cash.balanceOf(address(this));

        uint256 balanceOfVaultBefore = cash.balanceOf(address(vault));

        vault.withdraw(epochs, address(cash));

        uint256 finalBalanceOfCash = cash.balanceOf(address(this));

        uint256 balanceOfVaultAfter = cash.balanceOf(address(vault));

        assertGt(finalBalanceOfCash, initialBalanceOfCash, "User should have more balance of Cash value");

        assertLt(balanceOfVaultAfter, balanceOfVaultBefore, "Vault should have less balance of Cash value");

        // alice withdraws assets
        vm.startPrank(alice);
        uint256 initialAliceBalanceOfCash = cash.balanceOf(address(alice));

        uint256 balanceOfVaultBeforeAlice = cash.balanceOf(address(vault));

        vault.withdraw(epochs, address(cash));

        uint256 finalAliceBalanceOfCash = cash.balanceOf(address(alice));

        uint256 balanceOfVaultAfterAlice = cash.balanceOf(address(vault));

        assertGt(finalAliceBalanceOfCash, initialAliceBalanceOfCash, "Alice should have more balance of Cash value");

        assertLt(balanceOfVaultAfterAlice, balanceOfVaultBeforeAlice, "Vault should have less balance of Cash value");
        vm.stopPrank();
    }

    function test_deposit() public {
        // deposit assets for previous epoch
        uint256 epoch = governor.currentEpoch();
        vote.mint(address(spog), 1000e18);
        vm.startPrank(address(spog));
        vote.approve(address(vault), 1000e18);

        expectEmit();
        emit EpochAssetsDeposited(epoch, address(vote), 1000e18);
        vault.deposit(epoch, address(vote), 1000e18);
        vm.stopPrank();

        assertEq(vote.balanceOf(address(vault)), 1000e18);
    }
}
