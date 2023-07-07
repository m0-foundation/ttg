// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISPOGControlled {
    // Errors
    error AlreadyInitialized();
    error CallerIsNotSPOG();

    function spog() external view returns (address);

    function initializeSPOG(address spog) external;

    // function mint(address account, uint256 amount) external;

    // function MINTER_ROLE() external view returns (bytes32);
}
