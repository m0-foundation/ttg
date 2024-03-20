// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ZeroGovernor } from "../../src/ZeroGovernor.sol";

contract ZeroGovernorHarness is ZeroGovernor {
    constructor(
        address voteToken_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        uint256 emergencyProposalQuorumNumerator_,
        uint256 zeroProposalQuorumNumerator_,
        address[] memory allowedCashTokens_
    )
        ZeroGovernor(
            voteToken_,
            emergencyGovernorDeployer_,
            powerTokenDeployer_,
            standardGovernorDeployer_,
            bootstrapToken_,
            standardProposalFee_,
            emergencyProposalQuorumNumerator_,
            zeroProposalQuorumNumerator_,
            allowedCashTokens_
        )
    {}

    function setProposal(
        uint256 proposalId_,
        uint256 voteStart_,
        bool executed_,
        address proposer_,
        uint256 quorumNumerator_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) external {
        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
            executed: executed_,
            proposer: proposer_,
            quorumNumerator: uint16(quorumNumerator_),
            noWeight: noWeight_,
            yesWeight: yesWeight_
        });
    }

    function revertIfInvalidCalldata(bytes memory callData_) external pure {
        _revertIfInvalidCalldata(callData_);
    }
}
