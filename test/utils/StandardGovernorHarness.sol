// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { StandardGovernor } from "../../src/StandardGovernor.sol";

contract StandardGovernorHarness is StandardGovernor {
    constructor(
        address registrar_,
        address voteToken_,
        address emergencyGovernor_,
        address zeroGovernor_,
        address zeroToken_,
        address cashToken_,
        address vault_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    )
        StandardGovernor(
            registrar_,
            voteToken_,
            emergencyGovernor_,
            zeroGovernor_,
            zeroToken_,
            cashToken_,
            vault_,
            proposalFee_,
            maxTotalZeroRewardPerActiveEpoch_
        )
    {}

    function setProposal(uint256 proposalId_, uint256 voteStart_, uint256 voteEnd_) external {
        setProposal(proposalId_, voteStart_, voteEnd_, false, address(0), 0, 0);
    }

    function setProposal(
        uint256 proposalId_,
        uint256 voteStart_,
        uint256 voteEnd_,
        bool executed_,
        address proposer_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) public {
        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            voteEnd: uint16(voteEnd_),
            executed: executed_,
            proposer: proposer_,
            thresholdRatio: 0,
            quorumRatio: 0,
            noWeight: noWeight_,
            yesWeight: yesWeight_
        });
    }

    function setProposalFeeInfo(uint256 proposalId_, address cashToken_, uint256 fee_) external {
        _proposalFees[proposalId_] = ProposalFeeInfo({ cashToken: cashToken_, fee: fee_ });
    }

    function setNumberOfProposals(uint256 epoch_, uint256 count_) external {
        _numberOfProposals[epoch_] = count_;
    }

    function setNumberOfProposalsVotedOn(uint256 epoch_, address voter_, uint256 count_) external {
        _numberOfProposalsVotedOn[epoch_][voter_] = count_;
    }
}
