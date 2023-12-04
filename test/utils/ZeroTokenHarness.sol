// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ZeroToken } from "../../src/ZeroToken.sol";

contract ZeroTokenHarness is ZeroToken {
    constructor(
        address standardGovernorDeployer_,
        address[] memory initialAccounts_,
        uint256[] memory initialBalances_
    ) ZeroToken(standardGovernorDeployer_, initialAccounts_, initialBalances_) {}

    function pushBalance(address account_, uint256 startingEpoch_, uint256 balance_) external {
        _balances[account_].push(AmountSnap(uint16(startingEpoch_), uint240(balance_)));
    }

    function pushDelegatee(address account_, uint256 startingEpoch_, address delegatee) external {
        _delegatees[account_].push(AccountSnap(uint16(startingEpoch_), delegatee));
    }

    function pushVotes(address account_, uint256 startingEpoch_, uint256 votingPower) external {
        _votingPowers[account_].push(AmountSnap(uint16(startingEpoch_), uint240(votingPower)));
    }

    function pushTotalSupply(uint256 startingEpoch_, uint256 totalSupply_) external {
        _totalSupplies.push(AmountSnap(uint16(startingEpoch_), uint240(totalSupply_)));
    }
}
