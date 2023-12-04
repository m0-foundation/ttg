// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../lib/forge-std/src/Test.sol";
import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { IERC5805 } from "../../src/abstract/interfaces/IERC5805.sol";

library Invariants {
    // Invariant 1: Sum of all accounts' voting powers is equal to total supply.
    function checkInvariant1(address[] memory accounts_, address token_) internal view returns (bool success_) {
        uint256 totalSupply_ = IERC20(token_).totalSupply();
        uint256 totalVotingPower_;

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            totalVotingPower_ += IERC5805(token_).getVotes(accounts_[index_]);
        }

        console2.log("totalVotingPower_", totalVotingPower_);
        console2.log("totalSupply_", totalSupply_);

        success_ = totalVotingPower_ <= totalSupply_;
    }

    // Invariant 2: Sum of all account balances is equal to total supply.
    function checkInvariant2(address[] memory accounts_, address token_) internal view returns (bool success_) {
        uint256 totalSupply_ = IERC20(token_).totalSupply();
        uint256 totalBalance_;

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            totalBalance_ += IERC20(token_).balanceOf(accounts_[index_]);
        }

        console2.log("totalBalance_", totalBalance_);
        console2.log("totalSupply_", totalSupply_);

        success_ = totalBalance_ <= totalSupply_;
    }
}
