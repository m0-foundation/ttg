// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IBatchGovernor } from "../abstract/interfaces/IBatchGovernor.sol";

/**
 * @title  An instance of a BatchGovernor with a unique and limited set of possible proposals with proposal fees.
 * @author M^0 Labs
 */
interface IStandardGovernor is IBatchGovernor {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the cash token is set to `cashToken`.
     * @param  cashToken The address of the cash token taking effect.
     */
    event CashTokenSet(address indexed cashToken);

    /**
     * @notice Emitted when `voter` has voted on all the proposals in the current epoch `currentEpoch`.
     * @param  voter        The address of the account voting.
     * @param  currentEpoch The current epoch number as a clock value.
     */
    event HasVotedOnAllProposals(address indexed voter, uint256 indexed currentEpoch);

    /**
     * @notice Emitted when the proposal fee for the proposal, with identifier `proposalFee`, is sent to the vault.
     * @param  proposalId The unique identifier of the proposal.
     * @param  cashToken  The address of the cash token for this particular proposal fee.
     * @param  amount     The amount of cash token of the proposal fee.
     */
    event ProposalFeeSentToVault(uint256 indexed proposalId, address indexed cashToken, uint256 amount);

    /**
     * @notice Emitted when the proposal fee is set to `proposalFee`.
     * @param  proposalFee The amount of cash token required onwards to create proposals.
     */
    event ProposalFeeSet(uint256 proposalFee);

    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when the proposal fee for a yet defeated or yet expired proposal is trying to be moved.
     * @param  state The current state of the proposal.
     */
    error FeeNotDestinedForVault(ProposalState state);

    /// @notice Revert message when the Cash Token specified in the constructor is address(0).
    error InvalidCashTokenAddress();

    /// @notice Revert message when the Emergency Governor specified in the constructor is address(0).
    error InvalidEmergencyGovernorAddress();

    /// @notice Revert message when the Registrar specified in the constructor is address(0).
    error InvalidRegistrarAddress();

    /// @notice Revert message when the Vault specified in the constructor is address(0).
    error InvalidVaultAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the Zero Token specified in the constructor is address(0).
    error InvalidZeroTokenAddress();

    /// @notice Revert message when proposal fee trying to be moved to the vault is 0.
    error NoFeeToSend();

    /// @notice Revert message when the caller is not this contract itself nor the Emergency Governor.
    error NotSelfOrEmergencyGovernor();

    /// @notice Revert message when the caller is not the Zero Governor.
    error NotZeroGovernor();

    /// @notice Revert message when a token transfer, from this contract, fails.
    error TransferFailed();

    /// @notice Revert message when a token transferFrom fails.
    error TransferFromFailed();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sends the proposal fee for proposal `proposalId` to the vault, if it is Defeated or Expired.
     * @param  proposalId The unique identifier of the proposal.
     */
    function sendProposalFeeToVault(uint256 proposalId) external;

    /**
     * @notice Set the cash token and proposal fee to be used to create proposals going forward.
     * @param  newCashToken   The address of the new cash token.
     * @param  newProposalFee The amount of cash token required onwards to create proposals.
     */
    function setCashToken(address newCashToken, uint256 newProposalFee) external;

    /* ============ Proposal Functions ============ */

    /**
     * @notice One of the valid proposals. Adds `account` to `list` at the Registrar.
     * @param  list    The key for some list.
     * @param  account The address of some account to be added.
     */
    function addToList(bytes32 list, address account) external;

    /**
     * @notice One of the valid proposals. Removes `account` to `list` at the Registrar.
     * @param  list    The key for some list.
     * @param  account The address of some account to be removed.
     */
    function removeFromList(bytes32 list, address account) external;

    /**
     * @notice One of the valid proposals. Removes `accountToRemove` and adds `accountToAdd` to `list` at the Registrar.
     * @param  list            The key for some list.
     * @param  accountToRemove The address of some account to be removed.
     * @param  accountToAdd    The address of some account to be added.
     */
    function removeFromAndAddToList(bytes32 list, address accountToRemove, address accountToAdd) external;

    /**
     * @notice One of the valid proposals. Sets `key` to `value` at the Registrar.
     * @param  key   Some key.
     * @param  value Some value.
     */
    function setKey(bytes32 key, bytes32 value) external;

    /**
     * @notice One of the valid proposals. Sets the proposal fee of the Standard Governor.
     * @param  newProposalFee The new proposal fee.
     */
    function setProposalFee(uint256 newProposalFee) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the required amount of cashToken it costs an account to create a proposal.
    function proposalFee() external view returns (uint256);

    /**
     * @notice Returns all the proposal details for a proposal with identifier `proposalId`.
     * @param  proposalId The unique identifier of the proposal.
     * @return voteStart  The first clock value when voting on the proposal is allowed.
     * @return voteEnd    The last clock value when voting on the proposal is allowed.
     * @return state      The state of the proposal.
     * @return noVotes    The amount of votes cast against the proposal.
     * @return yesVotes   The amount of votes cast for the proposal.
     * @return proposer   The address of the account that created the proposal.
     */
    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint48 voteStart,
            uint48 voteEnd,
            ProposalState state,
            uint256 noVotes,
            uint256 yesVotes,
            address proposer
        );

    /**
     * @notice Returns the proposal fee information.
     * @param  proposalId The unique identifier of the proposal.
     * @return cashToken  The address of the cash token for this particular proposal fee.
     * @return amount     The amount of cash token of the proposal fee.
     */
    function getProposalFee(uint256 proposalId) external view returns (address cashToken, uint256 amount);

    /// @notice Returns the maximum amount of Zero Token that can be rewarded to all vote casters per active epoch.
    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256);

    /**
     * @notice Returns the number of proposals at epoch `epoch`.
     * @param  epoch The epoch as a clock value.
     * @return The number of proposals at epoch `epoch`.
     */
    function numberOfProposalsAt(uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns the number of proposals that were voted on at `epoch`.
     * @param  voter The address of some account.
     * @param  epoch The epoch as a clock value.
     * @return The number of proposals at `epoch`.
     */
    function numberOfProposalsVotedOnAt(address voter, uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns whether `voter` has voted on all proposals in `epoch`.
     * @param  voter The address of some account.
     * @param  epoch The epoch as a clock value.
     * @return Whether `voter` has voted on all proposals in `epoch`.
     */
    function hasVotedOnAllProposals(address voter, uint256 epoch) external view returns (bool);

    /// @notice Returns the address of the Cash Token.
    function cashToken() external view returns (address);

    /// @notice Returns the address of the Emergency Governor.
    function emergencyGovernor() external view returns (address);

    /// @notice Returns the address of the Registrar.
    function registrar() external view returns (address);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address);

    /// @notice Returns the address of the Zero Governor.
    function zeroGovernor() external view returns (address);

    /// @notice Returns the address of the Zero Token.
    function zeroToken() external view returns (address);
}
