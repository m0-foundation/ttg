// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IDualGovernor is IGovernorBySig {
    /******************************************************************************************************************\
    |                                                      Enums                                                       |
    \******************************************************************************************************************/

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

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event PowerTokenQuorumRatioSet(uint16 powerTokenQuorumRatio);

    event ProposalFeeRangeSet(uint256 minProposalFee, uint256 maxProposalFee);

    event ProposalFeeSet(uint256 proposalFee);

    event ZeroTokenQuorumRatioSet(uint16 zeroTokenQuorumRatio);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

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

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function BALLOT_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOT_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function ONE() external pure returns (uint256 one);

    function cashToken() external view returns (address cashToken);

    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            address proposer,
            uint16 voteStart,
            uint16 voteEnd,
            bool executed,
            ProposalType proposalType,
            ProposalState state,
            uint256 noPowerTokenVotes,
            uint256 yesPowerTokenVotes,
            uint256 noZeroTokenVotes,
            uint256 yesZeroTokenVotes
        );

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

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function emergencyAddToList(bytes32 list, address account) external;

    function emergencyRemoveFromList(bytes32 list, address account) external;

    function emergencyUpdateConfig(bytes32 key, bytes32 value_) external;

    function removeFromList(bytes32 list, address account) external;

    function reset() external;

    function setProposalFee(uint256 newProposalFee) external;

    function setProposalFeeRange(uint256 newMinProposalFee, uint256 newMaxProposalFee, uint256 newProposalFee) external;

    function setPowerTokenQuorumRatio(uint16 newPowerTokenQuorumRatio) external;

    function setZeroTokenQuorumRatio(uint16 newZeroTokenQuorumRatio) external;

    function updateConfig(bytes32 key, bytes32 value_) external;
}
