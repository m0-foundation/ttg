// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_InitialState is SPOG_Base {
    function test_SPOGHasSetInitialValuesCorrectly() public {
        (uint256 tax, uint256 inflatorTime, uint256 sellTime, uint256 inflator, uint256 reward, IERC20 cash) =
            spog.spogData();

        assertEq(address(cash), address(deployScript.cash()), "cash not set correctly");
        assertEq(inflator, deployScript.inflator(), "inflator not set correctly");
        assertEq(reward, deployScript.reward(), "reward not set correctly");
        assertEq(govSPOGVote.votingPeriod(), deployScript.voteTime(), "voteTime not set correctly");
        assertEq(govSPOGValue.votingPeriod(), deployScript.forkTime(), "forkTime not set correctly");
        assertEq(inflatorTime, deployScript.inflatorTime(), "inflatorTime not set correctly");
        assertEq(sellTime, deployScript.sellTime(), "sellTime not set correctly");
        assertEq(govSPOGVote.quorumNumerator(), deployScript.voteQuorum(), "voteQuorum not set correctly");
        assertEq(govSPOGValue.quorumNumerator(), deployScript.valueQuorum(), "valueQuorum not set correctly");
        assertEq(tax, deployScript.tax(), "tax not set correctly");
        assertEq(address(govSPOGVote.votingToken()), address(deployScript.vote()), "vote token not set correctly");
        assertEq(address(govSPOGValue.votingToken()), address(deployScript.value()), "value token not set correctly");
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assertEq(taxRangeMin, deployScript.taxRange(0), "taxRangeMin not set correctly");
        assertEq(taxRangeMax, deployScript.taxRange(1), "taxRangeMax not set correctly");
    }
}
