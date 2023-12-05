// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/**
 * @title Contract clock properties.
 * @dev   The interface as defined by EIP-6372: https://eips.ethereum.org/EIPS/eip-6372
 */
interface IERC6372 {
    /**
     * @notice Returns a machine-readable string description of the clock the contract is operating on.
     * @return Clock mode the contract is operating on.
     */
    function CLOCK_MODE() external view returns (string memory);

    /**
     * @notice Returns the current timepoint according to the mode the contract is operating on.
     * @return Current timepoint.
     */
    function clock() external view returns (uint48);
}
