// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

interface IPowerBootstrapToken {
    error LengthMismatch(uint256 accountsLength, uint256 balancesLength);

    function balanceOfAt(address account, uint256 epoch) external view returns (uint256 balance);

    function totalSupplyAt(uint256 epoch) external view returns (uint256 totalSupply);
}
