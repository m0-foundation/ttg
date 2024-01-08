// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IERC20Extended } from "../../../lib/common/src/interfaces/IERC20Extended.sol";

import { IERC5805 } from "./IERC5805.sol";

/// @title Extension for an ERC5805 token that uses epochs as its clock mode and delegation via IERC1271.
interface IEpochBasedVoteToken is IERC5805, IERC20Extended {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /// @notice Revert message when an number being casted to a uint240 exceeds the maximum uint240 value.
    error AmountExceedsUint240();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Changes the voting power delegation for `account` to `delegatee`.
     * @param  account   The purported address of the signing account.
     * @param  delegatee The address the voting power of `account` will be delegated to.
     * @param  nonce     The nonce used for the signature.
     * @param  expiry    The last block number where the signature is still valid.
     * @param  signature A byte array signature.
     */
    function delegateBySig(
        address account,
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        bytes memory signature
    ) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the token balance of `account` at a past clock value `epoch`.
     * @param  account The address of some account.
     * @param  epoch   The epoch number as a clock value.
     * @return The token balance `account` at `epoch`.
     */
    function pastBalanceOf(address account, uint256 epoch) external view returns (uint256);

    /**
     * @notice Returns the delegatee of `account` at a past clock value `epoch`.
     * @param  account The address of some account.
     * @param  epoch   The epoch number as a clock value.
     * @return The delegatee of the voting power of `account` at `epoch`.
     */
    function pastDelegates(address account, uint256 epoch) external view returns (address);

    /**
     * @notice Returns the total token supply at a past clock value `epoch`.
     * @param  epoch The epoch number as a clock value.
     * @return The total token supply at `epoch`.
     */
    function pastTotalSupply(uint256 epoch) external view returns (uint256);
}
