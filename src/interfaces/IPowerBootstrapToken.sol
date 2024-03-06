// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/**
 * @title  A token implementing the minimal interface to e used to bootstrap a Power Token contract.
 * @author M^0 Labs
 */
interface IPowerBootstrapToken {
    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when the length of some accounts array does not equal the length of some balances array.
     * @param  accountsLength The length of the accounts array.
     * @param  balancesLength The length of the balances array.
     */
    error ArrayLengthMismatch(uint256 accountsLength, uint256 balancesLength);

    /// @notice Revert message when the total supply is larger than `type(uint240).max`, rendering the contract
    ///         incompatible as a bootstrap token for the PowerToken.
    error TotalSupplyTooLarge();

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns the token balance of `account` at a past clock value `epoch`.
     * @param  account The address of some account.
     * @param  epoch   The epoch number as a clock value.
     * @return The token balance `account` at `epoch`.
     */
    function pastBalanceOf(address account, uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns the total token supply at a past clock value `epoch`.
     * @param  epoch The epoch number as a clock value.
     * @return The total token supply at `epoch`.
     */
    function pastTotalSupply(uint256 epoch) external view returns (uint256);
}
