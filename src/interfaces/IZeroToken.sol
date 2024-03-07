// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedVoteToken } from "../abstract/interfaces/IEpochBasedVoteToken.sol";

/**
 * @title  An instance of an EpochBasedVoteToken delegating minting control to a Standard Governor,
 *         and enabling range queries for past balances, voting powers, delegations, and  total supplies.
 * @author M^0 Labs
 */
interface IZeroToken is IEpochBasedVoteToken {
    /* ============ Custom Errors ============ */

    /**
     * @notice Revert message when the length of some accounts array does not equal the length of some balances array.
     * @param  accountsLength The length of the accounts array.
     * @param  balancesLength The length of the balances array.
     */
    error ArrayLengthMismatch(uint256 accountsLength, uint256 balancesLength);

    /// @notice Revert message when the Standard Governor Deployer specified in the constructor is address(0).
    error InvalidStandardGovernorDeployerAddress();

    /// @notice Revert message when the caller is not the Standard Governor.
    error NotStandardGovernor();

    /// @notice Revert message when the start of an inclusive range query is larger than the end.
    error StartEpochAfterEndEpoch();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Mints `amount` token to `recipient`.
     * @param  recipient The address of the account receiving minted token.
     * @param  amount    The amount of token to mint.
     */
    function mint(address recipient, uint256 amount) external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns an array of token balances of `account`
     *         between `startEpoch` and `endEpoch` past inclusive clocks.
     * @param  account    The address of some account.
     * @param  startEpoch The starting epoch number as a clock value.
     * @param  endEpoch   The ending epoch number as a clock value.
     * @return An array of token balances, each relating to an epoch in the inclusive range.
     */
    function pastBalancesOf(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory);

    /**
     * @notice Returns an array of total token supplies between `startEpoch` and `endEpoch` clocks inclusively.
     * @param  startEpoch The starting epoch number as a clock value.
     * @param  endEpoch   The ending epoch number as a clock value.
     * @return An array of total supplies, each relating to an epoch in the inclusive range.
     */
    function pastTotalSupplies(uint256 startEpoch, uint256 endEpoch) external view returns (uint256[] memory);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address);

    /// @notice Returns the address of the Standard Governor Deployer.
    function standardGovernorDeployer() external view returns (address);
}
