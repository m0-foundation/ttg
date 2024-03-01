// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IPowerBootstrapToken } from "./interfaces/IPowerBootstrapToken.sol";

// NOTE: This is a production-ready example of a token that can be used to bootstrap the PowerToken for the first time.

/// @title A token implementing the minimal interface to be used to bootstrap a Power Token contract.
/// @dev   The timepoints queried is ignored as this token is not time-dependent.
contract PowerBootstrapToken is IPowerBootstrapToken {
    /// @dev The total supply of token.
    uint256 internal immutable _totalSupply;

    /// @dev Mapping to keep track of token balances per account.
    mapping(address account => uint256 balance) internal _balances;

    /**
     * @notice Constructs a new PowerBootstrapToken contract.
     * @param  initialAccounts_ The initial accounts to mint tokens to.
     * @param  initialBalances_ The initial token balances to mint to each accounts.
     */
    constructor(address[] memory initialAccounts_, uint256[] memory initialBalances_) {
        uint256 accountsLength_ = initialAccounts_.length;
        uint256 balancesLength_ = initialBalances_.length;

        if (accountsLength_ != balancesLength_) revert ArrayLengthMismatch(accountsLength_, balancesLength_);

        uint256 totalSupply_;

        for (uint256 index_; index_ < accountsLength_; ++index_) {
            totalSupply_ += _balances[initialAccounts_[index_]] = initialBalances_[index_];
        }

        if (totalSupply_ >= type(uint240).max) revert TotalSupplyTooLarge();

        _totalSupply = totalSupply_;
    }

    /// @inheritdoc IPowerBootstrapToken
    function pastBalanceOf(address account_, uint256) external view returns (uint256) {
        return _balances[account_];
    }

    /// @inheritdoc IPowerBootstrapToken
    function pastTotalSupply(uint256) external view returns (uint256) {
        return _totalSupply;
    }
}
