// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

import { IEpochBasedInflationaryVoteToken } from "../../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedInflationaryVoteTokenHarness as Vote } from "../utils/EpochBasedInflationaryVoteTokenHarness.sol";
import { Invariants } from "../utils/Invariants.sol";
import { TestUtils } from "../utils/TestUtils.sol";

contract EpochBasedInflationaryVoteTokenFuzzTests is TestUtils {
    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _eric = makeAddr("eric");
    address internal _frank = makeAddr("frank");
    address internal _grace = makeAddr("grace");
    address internal _henry = makeAddr("henry");
    address internal _ivan = makeAddr("ivan");
    address internal _judy = makeAddr("judy");

    address[] internal _accounts = [_alice, _bob, _carol, _dave, _eric, _frank, _grace, _henry, _ivan, _judy];

    uint256 internal _participationInflation = 2_000; // 20% in basis points

    Vote internal _vote;

    function setUp() external {
        _vote = new Vote("Vote Epoch Token", "VOTE", 0, _participationInflation);
    }

    function testFuzz_full(uint256 seed_) external {
        vm.skip(true);

        for (uint256 index_; index_ < 1000; ++index_) {
            // console2.log(" ");

            assertTrue(Invariants.checkInvariant1(_accounts, address(_vote)), "Invariant 1 Failed.");
            assertTrue(Invariants.checkInvariant2(_accounts, address(_vote)), "Invariant 2 Failed.");

            uint256 seconds_ = ((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % PureEpochs._EPOCH_PERIOD) / 2;

            // console2.log("advance", seconds_, block.timestamp + seconds_);
            _jumpSeconds(seconds_);

            // console2.log("Epoch", PureEpochs.currentEpoch());

            address account1_ = _accounts[((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % _accounts.length)];
            address account2_;

            do {
                account2_ = _accounts[((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % _accounts.length)];
            } while (account1_ == account2_);

            uint256 account1Balance_ = _vote.balanceOf(account1_);

            if (PureEpochs.currentEpoch() % 2 == 1) {
                if (!_vote.hasParticipatedAt(account1_, PureEpochs.currentEpoch())) {
                    // 30% chance
                    // console2.log("markParticipation", account1_);

                    _vote.markParticipation(account1_);
                }

                if (!_vote.hasParticipatedAt(account2_, PureEpochs.currentEpoch())) {
                    // 30% chance
                    // console2.log("markParticipation", account2_);

                    _vote.markParticipation(account2_);
                }
            } else {
                if (((seed_ % 100) >= 60) && (account1Balance_ != 0)) {
                    // 40% chance
                    uint256 amount_ = _bound(
                        ((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % 100) + 1,
                        1,
                        account1Balance_ * 2
                    );

                    amount_ = amount_ >= account1Balance_ ? account1Balance_ : amount_; // 50% chance of entire balance,

                    // console2.log("transfer", account1_, account2_, amount_);

                    vm.prank(account1_);
                    _vote.transfer(account2_, amount_);

                    continue;
                }

                if (((seed_ % 100) >= 50)) {
                    // 10% chance
                    uint256 amount_ = ((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % 100) + 1;

                    // console2.log("mint", account1_, amount_);

                    _vote.mint(account1_, amount_);

                    continue;
                }

                if (_vote.delegates(account1_) != account2_) {
                    // 50% chance
                    // console2.log("delegate", account1_, account2_);

                    vm.prank(account1_);
                    _vote.delegate(account2_);

                    continue;
                }
            }
        }
    }
}
