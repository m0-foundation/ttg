// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/// @title A Deterministic deployer of contracts using CREATE.
interface IDeployer {
    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /**
     * @notice Returns the nonce used to pre deterministically compute the address of the next deployed contract.
     * @return The nonce value.
     */
    function nonce() external view returns (uint256);

    /**
     * @notice Returns the address of the last Standard Governor deployed by this contract.
     * @return Last deployed Standard Governor address.
     */
    function lastDeploy() external view returns (address);

    /**
     * @notice Returns the address of the new Standard Governor this contract will deploy
     * @return Next deployed Standard Governor address.
     */
    function nextDeploy() external view returns (address);
}
