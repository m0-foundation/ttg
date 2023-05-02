// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import "forge-std/console.sol";

contract ValueSPOGGovernorTest is SPOG_Base {
    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    function test_valueGov_StartOfNextVotingPeriod() public {
        uint256 votingPeriod = valueGovernor.votingPeriod();
        uint256 startOfNextEpoch = valueGovernor.startOfNextEpoch();

        assertTrue(startOfNextEpoch > block.number);
        assertEq(startOfNextEpoch, block.number + votingPeriod);
    }

    function test_value_gov_AccurateIncrementOfCurrentVotingPeriodEpoch() public {
        uint256 currentEpoch = valueGovernor.currentEpoch();

        assertEq(currentEpoch, 0); // initial value

        for (uint256 i = 0; i < 6; i++) {
            vm.roll(block.number + valueGovernor.votingDelay() + 1);

            currentEpoch = valueGovernor.currentEpoch();

            assertEq(currentEpoch, i + 1);
        }
    }

    function test_ValueTokenSupplyDoesNotInflateAtTheBeginningOfEachVotingPeriodWithoutActivity() public {
        uint256 spogValueSupplyBefore = spogValue.totalSupply();

        uint256 vaultVoteTokenBalanceBefore = spogValue.balanceOf(address(vault));

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + voteGovernor.votingDelay() + 1);

        uint256 spogValueSupplyAfterFirstPeriod = spogValue.totalSupply();

        assertEq(spogValueSupplyAfterFirstPeriod, spogValueSupplyBefore, "Vote token supply inflated incorrectly");

        // check that vault has received the vote inflationary supply
        uint256 vaultVoteTokenBalanceAfterFirstPeriod = spogValue.balanceOf(address(vault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstPeriod,
            vaultVoteTokenBalanceBefore,
            "Vault received an inaccurate vote inflationary supply"
        );

        // start of new epoch inflation is triggered
        vm.roll(block.number + deployScript.time() + 1);

        uint256 spogValueSupplyAfterSecondPeriod = spogValue.totalSupply();

        assertEq(
            spogValueSupplyAfterSecondPeriod,
            spogValueSupplyAfterFirstPeriod,
            "Vote token supply inflated incorrectly in the second period"
        );
    }

    function test_fallback() public {
        vm.expectRevert("SPOGGovernor: non-existent function");
        (bool success,) = address(valueGovernor).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, true);
    }

    function test_COUNTING_MODE() public {
        assertEq(valueGovernor.COUNTING_MODE(), "support=alpha&quorum=alpha");
    }
}
