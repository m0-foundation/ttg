// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IThresholdGovernor } from "../abstract/interfaces/IThresholdGovernor.sol";

/**
 * @title  An instance of a ThresholdGovernor with a unique and limited set of possible proposals.
 * @author M^0 Labs
 */
interface IEmergencyGovernor is IThresholdGovernor {
    /* ============ Custom Errors ============ */

    /// @notice Revert message when the Registrar specified in the constructor is address(0).
    error InvalidRegistrarAddress();

    /// @notice Revert message when the Standard Governor specified in the constructor is address(0).
    error InvalidStandardGovernorAddress();

    /// @notice Revert message when the Zero Governor specified in the constructor is address(0).
    error InvalidZeroGovernorAddress();

    /// @notice Revert message when the caller is not the Zero Governor.
    error NotZeroGovernor();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets the threshold ratio to use going forward for newly created proposals.
     * @param  newThresholdRatio The new threshold ratio.
     */
    function setThresholdRatio(uint16 newThresholdRatio) external;

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
    function setStandardProposalFee(uint256 newProposalFee) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the address of the Registrar.
    function registrar() external view returns (address);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address);

    /// @notice Returns the address of the Zero Governor.
    function zeroGovernor() external view returns (address);
}
