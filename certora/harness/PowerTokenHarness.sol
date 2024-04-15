// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { PowerToken } from "src/PowerToken.sol";

contract PowerTokenHarness is PowerToken {
    constructor(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_,
        address vault_
    ) PowerToken(bootstrapToken_, standardGovernor_, cashToken_, vault_) {}

    function isVotingEpoch(uint16 epoch) external pure returns (bool) {
        return _isVotingEpoch(epoch);
    }

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

    function getUnrealizedInflation(address account, uint16 lastEpoch) external view returns (uint240) {
        return _getUnrealizedInflation(account, lastEpoch);
    }

    function getParticipationsLength(address account) external view returns (uint256) {
        return _participations[account].length;
    }

    function participations(address account, uint256 index) external view returns (VoidSnap memory) {
        return _participations[account][index];
    }

    function getLastSync(address account, uint16 epoch) external view returns (uint16) {
        return _getLastSync(account, epoch);
    }

    function _getDelegatee(address account_, uint256 epoch_) internal view override returns (address) {
        address delegatee_ = super._getDelegatee(account_, epoch_);
        _delegateeHookCVL(delegatee_);
        return delegatee_;
    }

    function _delegateeHookCVL(address account_) internal pure {}
}
