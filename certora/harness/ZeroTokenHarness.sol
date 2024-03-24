// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ZeroToken } from "src/ZeroToken.sol";

contract ZeroTokenHarness is ZeroToken {

    constructor(
        address standardGovernorDeployer_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) ZeroToken(standardGovernorDeployer_, initialAccounts_, initialBalances_) {}

    function getBalancesLength(address account) external view returns (uint256) {
        return _balances[account].length;
    }

    function getDelegateessLength(address account) external view returns (uint256) {
        return _delegatees[account].length;
    }

    function getVotingPowersLength(address account) external view returns (uint256) {
        return _votingPowers[account].length;
    }

    function balances(address account, uint256 index) external view returns (AmountSnap memory) {
        return _balances[account][index];
    }

    function delegatees(address account, uint256 index) external view returns (AccountSnap memory) {
        return _delegatees[account][index];
    }

    function votingPowers(address account, uint256 index) external view returns (AmountSnap memory) {
        return _votingPowers[account][index];
    }

    function totalSupplies(uint256 index) external view returns (AmountSnap memory) {
        return _totalSupplies[index];
    }

    function unsafeAccessVotingPowers(address account, uint256 index) external view returns (AmountSnap memory) {
        return _unsafeAccess(_votingPowers[account], index);
    }

    function unsafeAccessDelegatees(address account, uint256 index) external view returns (AccountSnap memory) {
        return _unsafeAccess(_delegatees[account], index);
    }

    function _getDelegatee(address account_, uint256 epoch_) internal view override returns (address) {
        address delegatee_ = super._getDelegatee(account_, epoch_);
        _delegateeHookCVL(delegatee_);
        return delegatee_;
    }

    function _delegateeHookCVL(address account_) internal pure {}
}
