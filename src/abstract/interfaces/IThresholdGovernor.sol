// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IBatchGovernor } from "./IBatchGovernor.sol";

interface IThresholdGovernor is IBatchGovernor {
    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event ThresholdRatioSet(uint16 thresholdRatio);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidThresholdRatio();

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
            uint16 thresholdRatio,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer
        );

    function thresholdRatio() external view returns (uint16 thresholdRatio);
}
