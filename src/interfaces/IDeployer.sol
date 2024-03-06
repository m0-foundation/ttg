// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

/**
 * @title  A Deterministic deployer of contracts using CREATE.
 * @author M^0 Labs
 */
interface IDeployer {
    /// @notice Returns the nonce used to pre deterministically compute the address of the next deployed contract.
    function nonce() external view returns (uint256);

    /// @notice Returns the address of the last contract deployed by this contract.
    function lastDeploy() external view returns (address);

    /// @notice Returns the address of the next contract this contract will deploy.
    function nextDeploy() external view returns (address);
}
