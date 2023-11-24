// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IZeroGovernor is IGovernorBySig {
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

    error InvalidCashToken();

    error InvalidCashTokenAddress();

    error InvalidRegistrarAddress();

    error InvalidTarget();

    error InvalidTargetsLength();

    error InvalidThresholdRatio();

    error InvalidValue();

    error InvalidValuesLength();

    error InvalidVoteTokenAddress();

    error NoAllowedCashTokens();

    error NotSelf();

    error ProposalCannotBeExecuted();

    error ProposalDoesNotExist();

    error ProposalExists();

    error ProposalNotActive(ProposalState state);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function BALLOT_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOT_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_TYPEHASH() external pure returns (bytes32 typehash);

    function BALLOTS_WITH_REASON_TYPEHASH() external pure returns (bytes32 typehash);

    function ONE() external pure returns (uint256 one);

    function emergencyGovernor() external view returns (address emergencyGovernor);

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

    function isAllowedCashToken(address token) external view returns (bool isAllowed);

    function proposalFee() external view returns (uint256 proposalFee);

    function registrar() external view returns (address registrar);

    function standardGovernor() external view returns (address standardGovernor);

    function startingCashToken() external view returns (address startingCashToken);

    function thresholdRatio() external view returns (uint16 thresholdRatio);

    function voteToken() external view returns (address voteToken);

    /******************************************************************************************************************\
    |                                                Proposal Functions                                                |
    \******************************************************************************************************************/

    function resetToPowerHolders() external;

    function resetToZeroHolders() external;

    function setCashToken(address newCashToken, uint256 newProposalFee) external;

    function setEmergencyProposalThresholdRatio(uint16 newThresholdRatio) external;

    function setZeroProposalThresholdRatio(uint16 newThresholdRatio) external;
}
