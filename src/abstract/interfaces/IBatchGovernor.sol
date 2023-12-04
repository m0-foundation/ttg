// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IGovernor } from "./IGovernor.sol";

interface IBatchGovernor is IGovernor {
    /******************************************************************************************************************\
    |                                                      Enums                                                       |
    \******************************************************************************************************************/

    enum VoteType {
        No,
        Yes
    }

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyVoted();

    error ExecutionFailed(bytes data);

    error InvalidEpoch();

    error InvalidCallData();

    error InvalidCallDatasLength();

    error InvalidTarget();

    error InvalidTargetsLength();

    error InvalidValue();

    error InvalidValuesLength();

    error InvalidVoteTokenAddress();

    error NotSelf();

    error ProposalCannotBeExecuted();

    error ProposalDoesNotExist();

    error ProposalExists();

    error ProposalNotActive(ProposalState state);

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function castVoteBySig(
        address voter,
        uint256 proposalId,
        uint8 support,
        bytes memory signature
    ) external returns (uint256 weight);

    function castVotesBySig(
        uint256[] calldata proposalIds,
        uint8[] calldata support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    function castVotesBySig(
        address voter,
        uint256[] calldata proposalIds,
        uint8[] calldata support,
        bytes memory signature
    ) external returns (uint256 weight);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function BALLOTS_TYPEHASH() external pure returns (bytes32 typehash);

    function ONE() external pure returns (uint256 one);

    function hashProposal(bytes memory callData) external view returns (uint256 proposalId);

    function proposalFee() external view returns (uint256 proposalFee);

    function voteToken() external view returns (address voteToken);
}
