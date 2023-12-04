// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IBatchGovernor } from "./IBatchGovernor.sol";

interface IThresholdGovernor is IBatchGovernor {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidThresholdRatio();

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event ThresholdRatioSet(uint16 thresholdRatio);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint16 voteStart,
            uint16 voteEnd,
            bool executed,
            ProposalState state,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer,
            uint16 thresholdRatio
        );

    function thresholdRatio() external view returns (uint16 thresholdRatio);
}
