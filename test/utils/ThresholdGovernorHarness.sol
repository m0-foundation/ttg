// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ThresholdGovernor } from "../../src/abstract/ThresholdGovernor.sol";

contract ThresholdGovernorHarness is ThresholdGovernor {
    constructor(
        string memory name_,
        address voteToken_,
        uint16 thresholdRatio_
    ) ThresholdGovernor(name_, voteToken_, thresholdRatio_) {}

    function setHasVoted(uint256 proposalId_, address voter_) external {
        hasVoted[proposalId_][voter_] = true;
    }

    function setProposal(uint256 proposalId_, uint256 voteStart_, uint256 thresholdRatio_) external {
        setProposal(proposalId_, voteStart_, false, address(0), thresholdRatio_, 0, 0);
    }

    function setProposal(
        uint256 proposalId_,
        uint256 voteStart_,
        bool executed_,
        address proposer_,
        uint256 thresholdRatio_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) public {
        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            executed: executed_,
            proposer: proposer_,
            thresholdRatio: uint16(thresholdRatio_),
            noWeight: noWeight_,
            yesWeight: yesWeight_
        });
    }

    function _revertIfInvalidCalldata(bytes memory callData_) internal pure override {}
}
