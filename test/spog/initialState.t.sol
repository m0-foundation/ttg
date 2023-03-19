// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_InitialState is SPOG_Base {
    function test_SPOGHasSetInitialValuesCorrectly() public view {
        (
            uint256 tax,
            uint256 inflatorTime,
            uint256 sellTime,
            uint256 inflator,
            uint256 reward,
            IERC20 cash
        ) = spog.spogData();

        assert(address(cash) == address(deployScript.cash()));
        assert(inflator == deployScript.inflator());
        assert(reward == deployScript.reward());
        assert(govSPOGVote.votingPeriod() == deployScript.voteTime());
        assert(govSPOGValue.votingPeriod() == deployScript.forkTime());
        assert(inflatorTime == deployScript.inflatorTime());
        assert(sellTime == deployScript.sellTime());
        assert(govSPOGVote.quorumNumerator() == deployScript.voteQuorum());
        assert(govSPOGValue.quorumNumerator() == deployScript.valueQuorum());
        assert(tax == deployScript.tax());
        assert(
            address(govSPOGVote.votingToken()) == address(deployScript.vote())
        );
        assert(
            address(govSPOGValue.votingToken()) == address(deployScript.value())
        );
        // test tax range is set correctly
        (uint256 taxRangeMin, uint256 taxRangeMax) = spog.taxRange();
        assert(taxRangeMin == deployScript.taxRange(0));
        assert(taxRangeMax == deployScript.taxRange(1));
    }
}
