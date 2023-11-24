// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IStandardGovernor is IGovernorBySig {
    /******************************************************************************************************************\
    |                                                      Enums                                                       |
    \******************************************************************************************************************/

    enum VoteType {
        No,
        Yes
    }

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event CashTokenSet(address indexed cashToken);

    event ProposalFeeSet(uint256 proposalFee);

    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 proposalFee);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyVoted();

    error EpochHasNoProposals();

    error ExecutionFailed(bytes data);

    error FeeNotDestinedForVault(ProposalState state);

    error InvalidCallData();

    error InvalidCallDatasLength();

    error InvalidCashTokenAddress();

    error InvalidEmergencyGovernorAddress();

    error InvalidRegistrarAddress();

    error InvalidTarget();

    error InvalidTargetsLength();

    error InvalidValue();

    error InvalidValuesLength();

    error InvalidVaultAddress();

    error InvalidVoteTokenAddress();

    error InvalidZeroGovernorAddress();

    error InvalidZeroTokenAddress();

    error NotSelf();

    error NotSelfOrEmergencyGovernor();

    error NotZeroGovernor();

    error ProposalCannotBeExecuted();

    error ProposalDoesNotExist();

    error ProposalExists();

    error ProposalNotActive(ProposalState state);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function sendProposalFeeToVault(uint256 proposalId) external;

    function setCashToken(address newCashToken, uint256 newProposalFee_) external;

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
            uint16 voteStart,
            uint16 voteEnd,
            bool executed,
            ProposalState state,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer
        );

    function hashProposal(bytes memory callData) external view returns (uint256 proposalId);

    function hasVotedOnAllProposals(address voter, uint256 epoch) external view returns (bool hasVoted);

    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256 reward);

    function numberOfProposalsAt(uint256 epoch) external view returns (uint256 count);

    function numberOfProposalsVotedOnAt(uint256 epoch, address voter) external view returns (uint256 count);

    function proposalFee() external view returns (uint256 proposalFee);

    function registrar() external view returns (address registrar);

    function vault() external view returns (address vault);

    function voteToken() external view returns (address voteToken);

    function zeroToken() external view returns (address zeroToken);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function addAndRemoveFromList(bytes32 list, address accountToAdd, address accountToRemove) external;

    function removeFromList(bytes32 list, address account) external;

    function setProposalFee(uint256 newProposalFee) external;

    function updateConfig(bytes32 key, bytes32 value_) external;
}
