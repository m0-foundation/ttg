// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IGovernor } from "./IGovernor.sol";

/// @title Extension for Governor with specialized strict proposal parameters, vote batching, and an epoch clock.
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

    /// @notice Revert message when a voter is trying to vote on a proposal they already voted on.
    error AlreadyVoted();

    /**
     * @notice Revert message when execution of a proposal fails.
     * @param  data The revert data returned due to the failed execution.
     */
    error ExecutionFailed(bytes data);

    /// @notice Revert message when an invalid epoch is detected.
    error InvalidEpoch();

    /// @notice Revert message when a proposal's call data is not specifically supported.
    error InvalidCallData();

    /// @notice Revert message when a proposal's call data array is not of length 1.
    error InvalidCallDatasLength();

    /// @notice Revert message when a proposal target is no this governor itself.
    error InvalidTarget();

    /// @notice Revert message when a proposal's targets array is not of length 1.
    error InvalidTargetsLength();

    /// @notice Revert message when a proposal value is not 0 ETH.
    error InvalidValue();

    /// @notice Revert message when a an invalid vote start is detected.
    error InvalidVoteStart();

    /// @notice Revert message when a proposal's values array is not of length 1.
    error InvalidValuesLength();

    /// @notice Revert message when the vote token specified in the constructor is address(0).
    error InvalidVoteTokenAddress();

    /// @notice Revert message when the caller of a governance-controlled function is not this governor itself.
    error NotSelf();

    /// @notice Revert message when the proposal information provided cannot be executed.
    error ProposalCannotBeExecuted();

    /// @notice Revert message when the proposal does not exist.
    error ProposalDoesNotExist();

    /// @notice Revert message when the proposal already exists.
    error ProposalExists();

    /**
     * @notice Revert message when voting on a proposal that is not in an active state (i.e. not collecting votes).
     * @param  state The current state of the proposal.
     */
    error ProposalNotActive(ProposalState state);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Allows the caller to cast votes on multiple proposals.
     * @param  proposalIds The list of unique proposal IDs being voted on.
     * @param  supportList The list of support type per proposal IDs to cast.
     * @return weight      The number of votes cast for each proposal (the same for all of them).
     */
    function castVotes(uint256[] calldata proposalIds, uint8[] calldata supportList) external returns (uint256 weight);

    /**
     * @notice Allows a signer to cast votes on multiple proposals via an ECDSA secp256k1 signature.
     * @param  proposalIds The list of unique proposal IDs being voted on.
     * @param  supportList The list of support type per proposal IDs to cast.
     * @param  v           An ECDSA secp256k1 signature parameter.
     * @param  r           An ECDSA secp256k1 signature parameter.
     * @param  s           An ECDSA secp256k1 signature parameter.
     * @return weight      The number of votes cast for each proposal (the same for all of them).
     */
    function castVotesBySig(
        uint256[] calldata proposalIds,
        uint8[] calldata supportList,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    /**
     * @notice Allows a signer to cast votes on multiple proposals via an arbitrary signature.
     * @param  proposalIds The list of unique proposal IDs being voted on.
     * @param  supportList The list of support type per proposal IDs to cast.
     * @param  signature   An arbitrary signature
     * @return weight      The number of votes cast for each proposal (the same for all of them).
     */
    function castVotesBySig(
        address voter,
        uint256[] calldata proposalIds,
        uint8[] calldata supportList,
        bytes memory signature
    ) external returns (uint256 weight);

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the ballot digest to be signed, via EIP-712, given an internal digest (i.e. hash struct).
     * @param  proposalId The unique proposal ID being voted on.
     * @param  support    The type of support to cast for the proposal.
     * @return The digest to be signed.
     */
    function getBallotDigest(uint256 proposalId, uint8 support) external view returns (bytes32);

    /**
     * @notice Returns the ballots digest to be signed, via EIP-712, given an internal digest (i.e. hash struct).
     * @param  proposalIds The list of unique proposal IDs being voted on.
     * @param  supportList The list of support type per proposal IDs to cast.
     * @return The digest to be signed.
     */
    function getBallotsDigest(
        uint256[] calldata proposalIds,
        uint8[] calldata supportList
    ) external view returns (bytes32);

    /**
     * @notice Returns the unique identifier for the proposal if it were created at this exact moment.
     * @param  callData The single call data used to call this governor upon execution of a proposal.
     * @return The unique identifier for the proposal.
     */
    function hashProposal(bytes memory callData) external view returns (uint256);

    /// @notice Returns the EIP-5805 token contact used for determine voting power and total supplies.
    function voteToken() external view returns (address);

    /// @notice Returns the EIP712 typehash used in the encoding of the digest for the castVotesBySig function.
    function BALLOTS_TYPEHASH() external pure returns (bytes32);

    /// @notice Returns the value used as 100%, to be used to correctly ascertain the threshold ratio.
    function ONE() external pure returns (uint256);
}
