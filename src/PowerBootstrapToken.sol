// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IPowerBootstrapToken } from "./interfaces/IPowerBootstrapToken.sol";

// NOTE: This is an production-ready example of a token that can be used to bootstrap the PowerToken for the first time.

/// @title A token implementing the minimal interface to be used to bootstrap a Power Token contract.
/// @dev   The timepoints queried is ignored as this token is not time-dependent.
contract PowerBootstrapToken is IPowerBootstrapToken {
    uint256 internal immutable _totalSupply;

    mapping(address account => uint256 balance) internal _balances;

    constructor(address[] memory initialAccounts_, uint256[] memory initialBalances_) {
        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert LengthMismatch(accountsLength_, balancesLength_);

        uint256 totalSupply_;

        for (uint256 index_; index_ < accountsLength_; ++index_) {
            totalSupply_ += _balances[initialAccounts_[index_]] = initialBalances_[index_];
        }

        _totalSupply = totalSupply_;
    }

    function pastBalanceOf(address account_, uint256) external view returns (uint256 balance_) {
        return _balances[account_];
    }

    function pastTotalSupply(uint256) external view returns (uint256 totalSupply_) {
        return _totalSupply;
    }
}
