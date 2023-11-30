// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IGovernorBySig } from "./IGovernorBySig.sol";

interface IBatchGovernor is IGovernorBySig {
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

    error InvalidGovernorSignature(address voter);

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

    function hashProposal(bytes memory callData) external view returns (uint256 proposalId);

    function proposalFee() external view returns (uint256 proposalFee);

    function voteToken() external view returns (address voteToken);
}
