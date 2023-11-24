// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IEmergencyGovernor is IGovernorBySig {
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

    event ThresholdRatioSet(uint16 thresholdRatio);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyVoted();

    error ExecutionFailed(bytes data);

    error InvalidCallData();

    error InvalidCallDatasLength();

    error InvalidRegistrarAddress();

    error InvalidStandardGovernorAddress();

    error InvalidTarget();

    error InvalidTargetsLength();

    error InvalidThresholdRatio();

    error InvalidValue();

    error InvalidValuesLength();

    error InvalidVoteTokenAddress();

    error InvalidZeroGovernorAddress();

    error NotSelf();

    error NotZeroGovernor();

    error ProposalCannotBeExecuted();

    error ProposalDoesNotExist();

    error ProposalExists();

    error ProposalNotActive(ProposalState state);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function setThresholdRatio(uint16 newThresholdRatio) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function BALLOT_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOT_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function ONE() external pure returns (uint256 one);

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

    function hashProposal(bytes memory callData) external view returns (uint256 proposalId);

    function proposalFee() external view returns (uint256 proposalFee);

    function registrar() external view returns (address registrar);

    function standardGovernor() external view returns (address standardGovernor);

    function thresholdRatio() external view returns (uint16 thresholdRatio);

    function voteToken() external view returns (address voteToken);

    function zeroGovernor() external view returns (address zeroGovernor);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function addToList(bytes32 list, address account) external;

    function addAndRemoveFromList(bytes32 list, address accountToAdd, address accountToRemove) external;

    function removeFromList(bytes32 list, address account) external;

    function setStandardProposalFee(uint256 newProposalFee) external;

    function updateConfig(bytes32 key, bytes32 value_) external;
}
