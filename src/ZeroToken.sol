// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IZeroToken } from "./interfaces/IZeroToken.sol";

import { EpochBasedVoteToken } from "./EpochBasedVoteToken.sol";

contract ZeroToken is IZeroToken, EpochBasedVoteToken {
    address internal immutable _registrar;

    modifier onlGovernor() {
        if (msg.sender != IRegistrar(_registrar).governor()) revert NotGovernor();

        _;
    }

    constructor(
        address registrar_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) EpochBasedVoteToken("Zero Token", "ZERO", 6) {
        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert LengthMismatch(accountsLength_, balancesLength_);

        for (uint256 i; i < accountsLength_; i++) {
            _mint(initialAccounts_[i], initialBalances_[i]);
        }

        _registrar = registrar_;
    }

    function mint(address recipient, uint256 amount) external onlGovernor {
        _mint(recipient, amount);
    }

    function registrar() external view returns (address registrar_) {
        registrar_ = _registrar;
    }
}
