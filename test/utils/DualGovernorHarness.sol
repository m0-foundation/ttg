// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { DualGovernor } from "../../src/DualGovernor.sol";

contract DualGovernorHarness is DualGovernor {
    constructor(
        address registrar_,
        address cashToken_,
        address powerToken_,
        address zeroToken_,
        address vault_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_,
        uint256 powerTokenThresholdRatio_,
        uint256 zeroTokenThresholdRatio_
    )
        DualGovernor(
            registrar_,
            cashToken_,
            powerToken_,
            zeroToken_,
            vault_,
            proposalFee_,
            maxTotalZeroRewardPerActiveEpoch_,
            uint16(powerTokenThresholdRatio_),
            uint16(zeroTokenThresholdRatio_)
        )
    {}

    function setProposal(
        uint256 proposalId_,
        ProposalType proposalType_,
        uint256 voteStart_,
        uint256 voteEnd_,
        uint256 thresholdRatio_
    ) external {
        setProposal(proposalId_, proposalType_, voteStart_, voteEnd_, false, address(0), thresholdRatio_, 0, 0);
    }

    function setProposal(
        uint256 proposalId_,
        ProposalType proposalType_,
        uint256 voteStart_,
        uint256 voteEnd_,
        bool executed_,
        address proposer_,
        uint256 thresholdRatio_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) public {
        _proposals[proposalId_] = Proposal({
            proposalType: proposalType_,
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: executed_,
            proposer: proposer_,
            thresholdRatio: uint16(thresholdRatio_),
            noWeight: noWeight_,
            yesWeight: yesWeight_
        });
    }

    function setStandardProposals(uint256 epoch_, uint256 count_) external {
        _standardProposals[epoch_] = count_;
    }
}
