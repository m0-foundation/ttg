// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC712 } from "../../../lib/common/src/interfaces/IERC712.sol";

import { IERC6372 } from "./IERC6372.sol";

/**
 * @title  Minimal OpenZeppelin-style, Tally-compatible governor.
 * @author M^0 Labs
 */
interface IGovernor is IERC6372, IERC712 {
    /* ============ Enums ============ */

    /**
     * @notice Proposal state.
     * @param  Pending   The proposal has been created, but the vote has not started yet.
     * @param  Active    The proposal is currently in the voting period.
     * @param  Canceled  The proposal has been canceled.
     * @param  Defeated  The proposal has been defeated.
     * @param  Succeeded The proposal has succeeded.
     * @param  Queued    The proposal has been queued.
     * @param  Expired   The proposal has expired.
     * @param  Executed  The proposal has been executed.
     */
    enum ProposalState {
        Pending,
        Active,
        Canceled, // never used by TTG.
        Defeated,
        Succeeded,
        Queued, // never used by TTG.
        Expired,
        Executed
    }

    /* ============ Events ============ */

    /**
     * @notice Emitted when a proposal has been created.
     * @param  proposalId  The unique identifier for the proposal.
     * @param  proposer    The address of the account that created the proposal.
     * @param  targets     An array of addresses that will be called upon the execution.
     * @param  values      An array of ETH amounts that will be sent to each respective target upon execution.
     * @param  signatures  Empty string array required to be compatible with OZ governor contract.
     * @param  callDatas   An array of call data used to call each respective target upon execution.
     * @param  voteStart   The first clock value when voting on the proposal is allowed.
     * @param  voteEnd     The last clock value when voting on the proposal is allowed.
     * @param  description The string of the description of the proposal.
     */
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] callDatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );

    /**
     * @notice Emitted when a proposal has been executed.
     * @param  proposalId The unique identifier for the proposal.
     */
    event ProposalExecuted(uint256 proposalId);

    /**
     * @notice Emitted when a vote for a proposal with id `proposalId` has been cast by `voter`.
     * @param  voter      The address of the account that has casted their vote.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support that has been cast for the proposal.
     * @param  weight     The number of votes cast.
     * @param  reason     The string of the reason `voter` has cast their vote, if any.
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Allows the caller to cast a vote on a proposal with id `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @return weight     The number of votes cast.
     */
    function castVote(uint256 proposalId, uint8 support) external returns (uint256 weight);

    /**
     * @notice Allows a signer to cast a vote on a proposal with id `proposalId` via an ECDSA secp256k1 signature.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @param  v          An ECDSA secp256k1 signature parameter.
     * @param  r          An ECDSA secp256k1 signature parameter.
     * @param  s          An ECDSA secp256k1 signature parameter.
     * @return weight     The number of votes cast.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    /**
     * @notice Allows `voter` to cast a vote on a proposal with id `proposalId` via an arbitrary signature.
     * @param  voter      The address of the account that casting their vote, and purported the have signed.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @param  signature  An arbitrary signature.
     * @return weight     The number of votes cast.
     */
    function castVoteBySig(
        address voter,
        uint256 proposalId,
        uint8 support,
        bytes memory signature
    ) external returns (uint256 weight);

    /**
     * @notice Allows the caller to cast a vote with reason on a proposal with id `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @param  reason     The reason for which the caller casts their vote, if any.
     * @return weight     The number of votes cast.
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256 weight);

    /**
     * @notice Allows a signer to cast a vote with reason on a proposal with id `proposalId`
     *         via an ECDSA secp256k1 signature.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @param  reason     The reason for which the caller casts their vote, if any.
     * @param  v          An ECDSA secp256k1 signature parameter.
     * @param  r          An ECDSA secp256k1 signature parameter.
     * @param  s          An ECDSA secp256k1 signature parameter.
     * @return weight     The number of votes cast.
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    /**
     * @notice Allows `voter` to cast a vote with reason on a proposal with id `proposalId` via an arbitrary signature.
     * @param  voter      The address of the account that casting their vote, and purported the have signed.
     * @param  proposalId The unique identifier for the proposal.
     * @param  support    The type of support to cast for the proposal.
     * @param  reason     The reason for which the caller casts their vote, if any.
     * @param  signature  An arbitrary signature.
     * @return weight     The number of votes cast.
     */
    function castVoteWithReasonBySig(
        address voter,
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory signature
    ) external returns (uint256 weight);

    /**
     * @notice Allows the caller to execute a proposal.
     * @param  targets         An array of addresses that will be called upon the execution.
     * @param  values          An array of ETH amounts that will be sent to each respective target upon execution.
     * @param  callDatas       An array of call data used to call each respective target upon execution.
     * @param  descriptionHash The hash of the string of the description of the proposal.
     * @return proposalId      The unique identifier for the proposal.
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        bytes32 descriptionHash
    ) external payable returns (uint256 proposalId);

    /**
     * @notice Allows the caller to create a proposal.
     * @param  targets     An array of addresses that will be called upon the execution.
     * @param  values      An array of ETH amounts that will be sent to each respective target upon execution.
     * @param  callDatas   An array of call data used to call each respective target upon execution.
     * @param  description The string of the description of the proposal.
     * @return proposalId  The unique identifier for the proposal.
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        string memory description
    ) external returns (uint256 proposalId);

    /* ============ View/Pure Functions ============ */

    /**
     * @notice module:voting
     * @dev    A description of the possible "support" values for castVote and the way these votes are counted, meant to
     *         be consumed by UIs to show correct vote options and interpret the results. The string is a URL-encoded
     *         sequence of key-value pairs that each describe one aspect, for example `support=for,against&quorum=for`.
     *         The string can be decoded by the standard URLSearchParams JavaScript class.
     */
    function COUNTING_MODE() external view returns (string memory);

    /**
     * @notice Returns the voting power of `account` at clock value `timepoint`.
     * @param  account   The address of the account with voting power.
     * @param  timepoint The point in time, according to the clock mode the contract is operating on.
     * @return The voting power of `account` at `timepoint`.
     */
    function getVotes(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the unique identifier for the proposal if it were created at this exact moment.
     * @param  targets         An array of addresses that will be called upon the execution.
     * @param  values          An array of ETH amounts that will be sent to each respective target upon execution.
     * @param  callDatas       An array of call data used to call each respective target upon execution.
     * @param  descriptionHash The hash of the string of the description of the proposal.
     * @return The unique identifier for the proposal.
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        bytes32 descriptionHash
    ) external view returns (uint256);

    /**
     * @notice Returns whether `account` has voted on the proposal with identifier `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @param  account    The address of some account.
     * @return Whether `account` has already voted on the proposal.
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /// @notice Returns the name of the contract.
    function name() external view returns (string memory);

    /**
     * @notice Returns the last clock value when voting on the proposal with identifier `proposalId` is allowed.
     * @param  proposalId The unique identifier for the proposal.
     * @return The last clock value when voting on the proposal is allowed.
     */
    function proposalDeadline(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Returns the account that created the proposal with identifier `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @return The address of the account that created the proposal.
     */
    function proposalProposer(uint256 proposalId) external view returns (address);

    /**
     * @notice Returns the clock value used to retrieve voting power to vote on proposal with identifier `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @return The clock value used to retrieve voting power.
     */
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);

    /// @notice Returns the required voting power an account needs to create a proposal.
    function proposalThreshold() external view returns (uint256);

    /// @notice Returns the minimum number of eligible (COUNTING_MODE) votes for a proposal to succeed.
    function quorum() external view returns (uint256);

    /**
     * @notice Returns the minimum number of eligible (COUNTING_MODE) votes for a proposal to succeed at `timepoint`.
     * @param  timepoint The point in time, according to the clock mode the contract is operating on.
     * @return The quorum value at `timepoint`.
     */
    function quorum(uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the state of a proposal with identifier `proposalId`.
     * @param  proposalId The unique identifier for the proposal.
     * @return The state of the proposal.
     */
    function state(uint256 proposalId) external view returns (ProposalState);

    /// @notice Returns the number of clock values that must elapse before voting begins for a newly created proposal.
    function votingDelay() external view returns (uint256);

    /// @notice Returns the number of clock values between the vote start and vote end.
    function votingPeriod() external view returns (uint256);

    /// @notice Returns the EIP712 typehash used in the encoding of the digest for `castVoteBySig` function.
    function BALLOT_TYPEHASH() external pure returns (bytes32);

    /// @notice Returns the EIP712 typehash used in the encoding of the digest for `castVoteWithReasonBySig` function.
    function BALLOT_WITH_REASON_TYPEHASH() external pure returns (bytes32);
}
