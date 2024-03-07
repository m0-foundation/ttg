// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IStatefulERC712 } from "../../../lib/common/src/interfaces/IStatefulERC712.sol";

import { IERC6372 } from "./IERC6372.sol";

/**
 * @title  Voting with voting weight tracking and delegation support.
 * @author M^0 Labs
 * @dev    The interface as defined by EIP-5805: https://eips.ethereum.org/EIPS/eip-5805
 */
interface IERC5805 is IStatefulERC712, IERC6372 {
    /* ============ Events ============ */

    /**
     * @notice Emitted when `delegator` changes its voting power delegation from `fromDelegatee` to `toDelegatee`.
     * @param  delegator     The address of the account changing its voting power delegation.
     * @param  fromDelegatee The previous account the voting power of `delegator` was delegated to.
     * @param  toDelegatee   The new account the voting power of `delegator` is delegated to.
     */
    event DelegateChanged(address indexed delegator, address indexed fromDelegatee, address indexed toDelegatee);

    /**
     * @notice Emitted when the available voting power of `delegatee` changes from `previousBalance` to `newBalance`.
     * @param  delegatee       The address of the account whose voting power is changed.
     * @param  previousBalance The previous voting power of `delegatee`.
     * @param  newBalance      The new voting power of `delegatee`.
     */
    event DelegateVotesChanged(address indexed delegatee, uint256 previousBalance, uint256 newBalance);

    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when a query for past values is for a timepoint greater or equal to the current clock.
     * @param  timepoint The timepoint being queried.
     * @param  clock     The current timepoint.
     */
    error NotPastTimepoint(uint48 timepoint, uint48 clock);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Allows a calling account to change its voting power delegation to `delegatee`.
     * @param  delegatee The address of the account the caller's voting power will be delegated to.
     */
    function delegate(address delegatee) external;

    /**
     * @notice Changes the signing account's voting power delegation to `delegatee`.
     * @param  delegatee The address of the account the signing account's voting power will be delegated to.
     * @param  nonce     The nonce of the account delegating.
     * @param  expiry    The last block number where the signature is still valid.
     * @param  v         A signature parameter.
     * @param  r         A signature parameter.
     * @param  s         A signature parameter.
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the EIP712 typehash used in the encoding of the digest for the delegateBySig function.
    function DELEGATION_TYPEHASH() external view returns (bytes32);

    /**
     * @notice Returns the delegatee the voting power of `account` is delegated to.
     * @param  account The address of the account that can delegate its voting power.
     * @return The address of the account the voting power of `account` will be delegated to.
     */
    function delegates(address account) external view returns (address);

    /**
     * @notice Returns the total voting power of `account` at a past clock value `timepoint`.
     * @param  account   The address of some account.
     * @param  timepoint The point in time, according to the clock mode the contract is operating on.
     * @return The total voting power of `account` at clock value `timepoint`.
     */
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);

    /**
     * @notice Returns the total voting power of `account`.
     * @param  account The address of some account.
     * @return The total voting power of `account`.
     */
    function getVotes(address account) external view returns (uint256);
}
