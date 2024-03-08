// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { EpochBasedVoteToken } from "../../src/abstract/EpochBasedVoteToken.sol";

contract EpochBasedVoteTokenHarness is EpochBasedVoteToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) EpochBasedVoteToken(name_, symbol_, uint8(decimals_)) {}

    function pushBalance(address account_, uint256 startingEpoch_, uint256 balance_) external {
        _balances[account_].push(AmountSnap(uint16(startingEpoch_), uint240(balance_)));
    }

    function pushDelegatee(address account_, uint256 startingEpoch_, address delegatee_) external {
        _delegatees[account_].push(AccountSnap(uint16(startingEpoch_), _getDefaultIfZero(delegatee_, account_)));
    }

    function pushVotes(address account_, uint256 startingEpoch_, uint256 votingPower) external {
        _votingPowers[account_].push(AmountSnap(uint16(startingEpoch_), uint240(votingPower)));
    }

    function pushTotalSupply(uint256 startingEpoch_, uint256 totalSupply_) external {
        _totalSupplies.push(AmountSnap(uint16(startingEpoch_), uint240(totalSupply_)));
    }

    function mint(address account_, uint256 amount_) external {
        _mint(account_, amount_);
    }
}
