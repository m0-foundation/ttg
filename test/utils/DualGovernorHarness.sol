// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { DualGovernor } from "../../src/DualGovernor.sol";

contract DualGovernorHarness is DualGovernor {
    constructor(
        address cashToken_,
        address registrar_,
        address zeroToken_,
        address powerToken_,
        address vault_,
        uint256 proposalFee_,
        uint256 minProposalFee_,
        uint256 maxProposalFee_,
        uint256 reward_,
        uint16 zeroTokenQuorumRatio_,
        uint16 powerTokenQuorumRatio_
    )
        DualGovernor(
            cashToken_,
            registrar_,
            zeroToken_,
            powerToken_,
            vault_,
            proposalFee_,
            minProposalFee_,
            maxProposalFee_,
            reward_,
            zeroTokenQuorumRatio_,
            powerTokenQuorumRatio_
        )
    {}

    function setProposal(
        uint256 proposalId_,
        address proposer_,
        uint256 voteStart_,
        uint256 voteEnd_,
        bool executed_,
        ProposalType proposalType_
    ) external {
        _proposals[proposalId_] = Proposal({
            proposer: proposer_,
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: executed_,
            proposalType: proposalType_
        });
    }

    function setNumberOfProposals(uint256 epoch_, uint256 numberOfProposals_) external {
        _numberOfProposals[epoch_] = numberOfProposals_;
    }
}
