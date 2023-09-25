// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IDualGovernor is IGovernorBySig {
    enum ProposalType {
        Power,
        Double,
        Zero,
        Emergency
    }

    enum VoteType {
        No,
        Yes
    }

    event ProposalFeeSet(uint256 proposalFee);

    event ProposalFeeRangeSet(uint256 minProposalFee, uint256 maxProposalFee);

    event ZeroTokenQuorumRatioSet(uint16 zeroTokenQuorumRatio);

    event PowerTokenQuorumRatioSet(uint16 powerTokenQuorumRatio);

    error AlreadyVoted();

    error EpochHasNoProposals();

    error ExecutionFailed(bytes data);

    error InvalidCalldatasLength();

    error InvalidPowerTokenAddress();

    error InvalidProposalFeeRange();

    error InvalidProposalType();

    error InvalidTarget();

    error InvalidTargetsLength();

    error InvalidValue();

    error InvalidValuesLength();

    error InvalidZeroTokenAddress();

    error NotSelf();

    error ProposalDoesNotExist();

    error ProposalExists();

    error ProposalFeeOutOfRange(uint256 minProposalFee, uint256 maxProposalFee);

    error ProposalIsNotInActiveState(ProposalState state);

    error ProposalNotSuccessful();

    error ZeroCashTokenAddress();

    error ZeroRegistrarAddress();

    function cashToken() external view returns (address cashToken);

    function maxProposalFee() external view returns (uint256 maxProposalFee);

    function minProposalFee() external view returns (uint256 minProposalFee);

    function numberOfProposals(uint256 epoch) external view returns (uint256 numberOfProposals);

    function numberOfProposalsVotedOn(
        uint256 epoch,
        address voter
    ) external view returns (uint256 numberOfProposalsVotedOn);

    function powerToken() external view returns (address powerToken);

    function powerTokenQuorumRatio() external view returns (uint256 powerTokenQuorumRatio);

    function proposalFee() external view returns (uint256 proposalFee);

    function registrar() external view returns (address registrar);

    function reward() external view returns (uint256 reward);

    function zeroToken() external view returns (address zeroToken);

    function zeroTokenQuorumRatio() external view returns (uint256 zeroTokenQuorumRatio);
}
