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

    uint240 internal _participationInflation = 2_000; // 20% in basis points

    uint16 public constant ONE = 10_000;

    Vote internal _vote;

    function setUp() external {
        _vote = new Vote("Vote Epoch Token", "VOTE", 0, _participationInflation);
    }

    function testFuzz_full(uint256 seed_) external {
        vm.skip(false);

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

    function testFuzz_inflationFromVotingPowerInPreviousEpoch_selfDelegation(
        uint240 amount,
        uint240 amountToTransfer
    ) external {
        amount = uint240(bound(amount, 1, type(uint128).max));
        amountToTransfer = uint240(bound(amountToTransfer, 0, amount));
        _warpToNextTransferEpoch();

        _vote.mint(_alice, amount);

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), amount);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), amount);

        _vote.markParticipation(_alice);

        assertEq(_vote.balanceOf(_alice), amount);
        amount = amount + ((amount * _participationInflation) / ONE);
        assertEq(_vote.getVotes(_alice), amount);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), amount);

        vm.prank(_alice);
        _vote.transfer(_bob, amountToTransfer);

        uint240 aliceAmountAfterTransfer = amount - amountToTransfer;
        assertEq(_vote.balanceOf(_alice), aliceAmountAfterTransfer);
        assertEq(_vote.getVotes(_alice), aliceAmountAfterTransfer);

        assertEq(_vote.balanceOf(_bob), amountToTransfer);
        assertEq(_vote.getVotes(_bob), amountToTransfer);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), aliceAmountAfterTransfer);
        assertEq(_vote.getVotes(_alice), aliceAmountAfterTransfer);

        assertEq(_vote.balanceOf(_bob), amountToTransfer);
        assertEq(_vote.getVotes(_bob), amountToTransfer);
    }

    function testFuzz_inflationFromVotingPowerInPreviousEpoch_delegated(
        uint240 amount,
        uint240 amountToTransfer
    ) external {
        amount = uint240(bound(amount, 1, type(uint128).max));
        amountToTransfer = uint240(bound(amountToTransfer, 0, amount));
        _warpToNextTransferEpoch();

        _vote.mint(_alice, amount);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), amount);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), amount);

        _vote.markParticipation(_bob);

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        amount = amount + ((amount * _participationInflation) / ONE);
        assertEq(_vote.getVotes(_bob), amount);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), amount);

        vm.prank(_alice);
        _vote.transfer(_bob, amountToTransfer);

        vm.prank(_alice);
        _vote.delegate(_alice);

        uint240 aliceAmountAfterTransfer = amount - amountToTransfer;
        assertEq(_vote.balanceOf(_alice), aliceAmountAfterTransfer);
        assertEq(_vote.getVotes(_alice), aliceAmountAfterTransfer);

        assertEq(_vote.balanceOf(_bob), amountToTransfer);
        assertEq(_vote.getVotes(_bob), amountToTransfer);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), aliceAmountAfterTransfer);
        assertEq(_vote.getVotes(_alice), aliceAmountAfterTransfer);

        assertEq(_vote.balanceOf(_bob), amountToTransfer);
        assertEq(_vote.getVotes(_bob), amountToTransfer);
    }

    function testFuzz_UsersVoteInflationUpgradeOnDelegation(uint240 amount) external {
        amount = uint240(bound(amount, 1, type(uint128).max));
        _warpToNextTransferEpoch();

        _vote.mint(_alice, amount);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_carol);

        amount = amount + ((amount * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_alice), amount);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), amount);

        _warpToNextVoteEpoch();

        uint240 amountCarol = amount + ((amount * _participationInflation) / ONE);
        _vote.markParticipation(_carol);

        assertEq(_vote.getVotes(_carol), amountCarol);
        assertEq(_vote.balanceOf(_alice), amount);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), amountCarol);
    }

    function testFuzz_VotingPowerForDelegates(
        uint240 amountAlice,
        uint240 amountBob,
        uint240 amountCarol,
        uint240 amountToTransferFromAlice,
        uint240 amountToTransferFromCarol
    ) external {
        amountAlice = uint240(bound(amountAlice, 1, type(uint128).max));
        amountBob = uint240(bound(amountBob, 1, type(uint128).max));
        amountCarol = uint240(bound(amountCarol, 1, type(uint128).max));
        amountToTransferFromAlice = uint240(bound(amountToTransferFromAlice, 0, amountAlice));
        amountToTransferFromCarol = uint240(bound(amountToTransferFromCarol, 0, amountCarol));

        _warpToNextTransferEpoch();

        _vote.mint(_alice, amountAlice);
        _vote.mint(_bob, amountBob);
        _vote.mint(_carol, amountCarol);

        vm.prank(_alice);
        _vote.delegate(_carol);

        vm.prank(_bob);
        _vote.delegate(_carol);

        assertEq(_vote.balanceOf(_alice), amountAlice);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), amountBob);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), amountCarol);
        assertEq(_vote.getVotes(_carol), amountAlice + amountBob + amountCarol);

        _warpToNextVoteEpoch();

        uint256 inflatedVotesAfterParticipation = _vote.getVotes(_carol) +
            ((_vote.getVotes(_carol) * _participationInflation) / ONE);
        _vote.markParticipation(_carol);

        _warpToNextTransferEpoch();

        amountAlice = amountAlice + ((amountAlice * _participationInflation) / ONE);
        amountBob = amountBob + ((amountBob * _participationInflation) / ONE);
        amountCarol = amountCarol + ((amountCarol * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_alice), amountAlice);
        assertEq(_vote.balanceOf(_bob), amountBob);
        assertEq(_vote.balanceOf(_carol), amountCarol);

        assertEq(_vote.getVotes(_carol), inflatedVotesAfterParticipation); //votes delegated to carol are properly inflated.
        assertApproxEqAbs(
            _vote.getVotes(_carol),
            _vote.balanceOf(_alice) + _vote.balanceOf(_carol) + _vote.balanceOf(_bob),
            2
        );

        vm.prank(_alice);
        _vote.transfer(_bob, amountToTransferFromAlice);

        assertApproxEqAbs(
            _vote.getVotes(_carol),
            _vote.balanceOf(_alice) + _vote.balanceOf(_carol) + _vote.balanceOf(_bob),
            2
        );

        vm.prank(_carol);
        _vote.transfer(_bob, amountToTransferFromCarol);

        assertApproxEqAbs(
            _vote.getVotes(_carol),
            _vote.balanceOf(_alice) + _vote.balanceOf(_carol) + _vote.balanceOf(_bob),
            2
        );

        vm.prank(_bob);
        _vote.delegate(_bob);

        assertApproxEqAbs(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_carol), 2);
        assertEq(_vote.getVotes(_bob), _vote.balanceOf(_bob));
    }

    function testFuzz_UsersVoteInflationForMultipleEpochsWithRedelegation(
        uint240 amountAlice,
        uint240 amountBob,
        uint240 amountCarol
    ) external {
        amountAlice = uint240(bound(amountAlice, 1, type(uint128).max));
        amountBob = uint240(bound(amountBob, 1, type(uint128).max));
        amountCarol = uint240(bound(amountCarol, 1, type(uint128).max));
        _warpToNextTransferEpoch();

        _vote.mint(_alice, amountAlice);
        _vote.mint(_bob, amountBob);
        _vote.mint(_carol, amountCarol);

        vm.prank(_alice);
        _vote.delegate(_carol);

        vm.prank(_bob);
        _vote.delegate(_carol);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol);

        uint256 totalAmount = amountCarol + amountAlice + amountBob;
        totalAmount = totalAmount + ((totalAmount * _participationInflation) / ONE);
        assertEq(_vote.getVotes(_carol), totalAmount);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), amountAlice);
        assertEq(_vote.balanceOf(_bob), amountBob);
        assertEq(_vote.balanceOf(_carol), amountCarol);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        amountAlice = amountAlice + ((amountAlice * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_alice), amountAlice);
        amountBob = amountBob + ((amountBob * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_bob), amountBob);
        amountCarol = amountCarol + ((amountCarol * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_carol), amountCarol);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_bob), amountAlice);
        assertApproxEqAbs(_vote.getVotes(_carol), _vote.balanceOf(_carol) + _vote.balanceOf(_bob), 2);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol); // carol votes, but bob doesn't

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), amountAlice);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), amountAlice);
        assertEq(_vote.balanceOf(_bob), amountBob);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), amountAlice);
        amountBob = amountBob + ((amountBob * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_bob), amountBob);
        amountCarol = amountCarol + ((amountCarol * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_carol), amountCarol);
    }

    function testFuzz_UsersVoteInflationForMultipleEpochsWithTransfers(
        uint240 amount,
        uint240 amountToTransferToCarol,
        uint240 amountToTransferToBob
    ) external {
        amount = uint240(bound(amount, 0, type(uint128).max));
        amountToTransferToCarol = uint240(bound(amountToTransferToCarol, 0, amount));
        amountToTransferToBob = uint240(bound(amountToTransferToBob, 0, amount));
        vm.assume(amountToTransferToBob + amountToTransferToCarol < amount);

        _warpToNextTransferEpoch();

        _vote.mint(_alice, amount);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), amount);

        vm.prank(_alice);
        _vote.transfer(_carol, amountToTransferToCarol);
        uint240 votesBob = amount - amountToTransferToCarol;

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), votesBob);
        assertEq(_vote.getVotes(_carol), amountToTransferToCarol);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_alice);
        _vote.markParticipation(_bob);
        _vote.markParticipation(_carol);

        assertEq(_vote.getVotes(_alice), 0);
        uint240 votesInflatedBob = votesBob + ((votesBob * _participationInflation) / ONE);
        assertEq(_vote.getVotes(_bob), votesInflatedBob);
        uint240 votesInflatedCarol = amountToTransferToCarol +
            ((amountToTransferToCarol * _participationInflation) / ONE);
        assertEq(_vote.getVotes(_carol), votesInflatedCarol);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), votesBob);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), amountToTransferToCarol);

        // attempt to transfer fails
        vm.expectRevert(IEpochBasedInflationaryVoteToken.VoteEpoch.selector);

        vm.prank(_alice);
        _vote.transfer(_bob, amountToTransferToBob);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), votesInflatedBob);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), votesInflatedCarol);

        vm.prank(_alice);
        _vote.transfer(_bob, votesInflatedBob);

        vm.prank(_carol);
        _vote.transfer(_bob, votesInflatedCarol);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), votesInflatedBob + votesInflatedCarol);
        assertEq(_vote.getVotes(_carol), 0);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), votesInflatedBob + votesInflatedCarol);
        assertEq(_vote.balanceOf(_carol), 0);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), votesInflatedBob + votesInflatedCarol);
        assertEq(_vote.balanceOf(_carol), 0);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), 0);
        uint240 votesInflatedBob2 = votesInflatedCarol +
            votesInflatedBob +
            (((votesInflatedCarol + votesInflatedBob) * _participationInflation) / ONE);
        assertEq(_vote.balanceOf(_bob), votesInflatedBob2);
        assertEq(_vote.balanceOf(_carol), 0);
    }
}
