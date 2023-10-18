// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { console2 } from "../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../src/PureEpochs.sol";

import { EpochBasedInflationaryVoteTokenHarness as Vote } from "./utils/EpochBasedInflationaryVoteTokenHarness.sol";
import { Invariants } from "./utils/Invariants.sol";

import { TestUtils } from "./utils/TestUtils.sol";

// TODO: test_UsersVoteInflationUpgradeOnDelegation
// TODO: test_UsersVoteInflationWorksWithTransfer
// TODO: test_UserGetRewardOnlyOncePerEpochIfRedelegating
// TODO: test_UserDoesNotGetDelayedRewardWhileRedelegating
// TODO: test_VotingPowerForDelegates
// TODO: test_VotingInflationWithRedelegationInTheSameEpoch
// TODO: test_UsersVoteInflationForMultipleEpochsWithRedelegation
// TODO: test_UsersVoteInflationForMultipleEpochsWithTransfers

contract EpochBasedInflationaryVoteTokenTests is TestUtils {
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

    uint256 internal _participationInflation = 2_000;

    Vote internal _vote;

    function setUp() external {
        _vote = new Vote("Vote Epoch Token", "VOTE", _participationInflation);
    }

    function test_noInflationWithoutVotingPowerInPreviousEpoch_selfDelegation() external {
        _goToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        _vote.markParticipation(_alice);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        _vote.mint(_alice, 1_000);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 500);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);

        _goToNextTransferEpoch();
        _goToNextTransferEpoch();
        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 500);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_noInflationWithoutVotingPowerInPreviousEpoch_delegated() external {
        _goToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _vote.markParticipation(_bob);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 1_000);

        _goToNextTransferEpoch();
        _goToNextTransferEpoch();
        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 1_000);
    }

    function test_inflationFromVotingPowerInPreviousEpoch_selfDelegation() external {
        _goToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        _goToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        _vote.markParticipation(_alice);

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 1_200);

        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 1_200);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);

        _goToNextTransferEpoch();
        _goToNextTransferEpoch();
        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_inflationFromVotingPowerInPreviousEpoch_delegated() external {
        _goToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        _goToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        _vote.markParticipation(_bob);

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_200);

        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_200);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        vm.prank(_alice);
        _vote.delegate(_alice);

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);

        _goToNextTransferEpoch();
        _goToNextTransferEpoch();
        _goToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_scenario1() external {
        _goToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _goToNextVoteEpoch();

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _goToNextVoteEpoch();

        _vote.markParticipation(_bob); // (1000 * 1.2) * 1.2 = 1440

        _goToNextTransferEpoch();
        _goToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_alice);

        _goToNextVoteEpoch();

        _vote.markParticipation(_alice); // ((1000 * 1.2) * 1.2) * 1.2 = 1728
        _vote.markParticipation(_bob);

        _goToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _goToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_bob);

        _goToNextVoteEpoch();

        _vote.markParticipation(_bob); // (((1000 * 1.2) * 1.2) * 1.2) * 1.2 = 2073

        _goToNextVoteEpoch();

        _vote.markParticipation(_bob); // ((((1000 * 1.2) * 1.2) * 1.2) * 1.2) * 1.2 = 2487

        assertEq(_vote.balanceOf(_alice), 2_487);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 2_487);
    }

    function testFuzz_full(uint256 seed_) external {
        vm.skip(false);

        for (uint256 index_; index_ < 1000; ++index_) {
            // console2.log(" ");

            assertTrue(Invariants.checkInvariant1(_accounts, address(_vote)), "Invariant 1 Failed.");
            assertTrue(Invariants.checkInvariant2(_accounts, address(_vote)), "Invariant 2 Failed.");

            uint256 blocks = ((seed_ = uint256(keccak256(abi.encodePacked(seed_)))) % PureEpochs._EPOCH_PERIOD) / 2;
            // console2.log("advance", blocks, block.number + blocks);
            _jumpBlocks(blocks);

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
