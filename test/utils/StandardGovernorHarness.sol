// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { StandardGovernor, BatchGovernor } from "../../src/StandardGovernor.sol";

contract StandardGovernorHarness is StandardGovernor {
    constructor(
        address voteToken_,
        address emergencyGovernor_,
        address zeroGovernor_,
        address cashToken_,
        address registrar_,
        address vault_,
        address zeroToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    )
        StandardGovernor(
            voteToken_,
            emergencyGovernor_,
            zeroGovernor_,
            cashToken_,
            registrar_,
            vault_,
            zeroToken_,
            proposalFee_,
            maxTotalZeroRewardPerActiveEpoch_
        )
    {}

    function getDigest(bytes32 internalDigest_) external view returns (bytes32) {
        return _getDigest(internalDigest_);
    }

    function getReasonListHash(string[] calldata reasonList_) external pure returns (bytes32) {
        return _getReasonListHash(reasonList_);
    }

    function revertIfInvalidCalldata(bytes memory callData_) external pure {
        return _revertIfInvalidCalldata(callData_);
    }

    function setHasVoted(uint256 proposalId_, address voter_) external {
        hasVoted[proposalId_][voter_] = true;
    }

    function setProposal(uint256 proposalId_, uint256 voteStart_) external {
        setProposal(proposalId_, voteStart_, false, address(0), 0, 0);
    }

    function setProposal(
        uint256 proposalId_,
        uint256 voteStart_,
        bool executed_,
        address proposer_,
        uint256 noWeight_,
        uint256 yesWeight_
    ) public {
        _proposals[proposalId_] = Proposal({
            voteStart: uint16(voteStart_),
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
        numberOfProposalsAt[epoch_] = count_;
    }

    function setNumberOfProposalsVotedOn(address voter_, uint256 epoch_, uint256 count_) external {
        numberOfProposalsVotedOnAt[voter_][epoch_] = count_;
    }
}
