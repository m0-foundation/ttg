// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IEpochBasedInflationaryVoteToken } from "../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { EpochBasedInflationaryVoteTokenHarness as Vote } from "./utils/EpochBasedInflationaryVoteTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

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

    uint256 internal _participationInflation = 2_000; // 20% in basis points

    Vote internal _vote;

    function setUp() external {
        _vote = new Vote("Vote Epoch Token", "VOTE", 0, _participationInflation);
    }

    function test_noInflationWithoutVotingPowerInPreviousEpoch_selfDelegation() external {
        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        _vote.markParticipation(_alice);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        _warpToNextTransferEpoch();

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

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 500);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_noInflationWithoutVotingPowerInPreviousEpoch_delegated() external {
        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _vote.markParticipation(_bob);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        _vote.mint(_alice, 1_000);

        assertEq(_vote.delegates(_alice), _alice);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.delegates(_alice), _bob);

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

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 500);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 1_000);
    }

    function test_inflationFromVotingPowerInPreviousEpoch_selfDelegation() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        _vote.markParticipation(_alice);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_200);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 1_200);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_inflationFromVotingPowerInPreviousEpoch_delegated() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        _vote.markParticipation(_bob);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_200);

        _warpToNextTransferEpoch();

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

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 700);

        assertEq(_vote.balanceOf(_bob), 500);
        assertEq(_vote.getVotes(_bob), 500);
    }

    function test_noDelegationsDuringVotingEpoch() external {
        _warpToNextVoteEpoch();

        // alice attempts to delegate to bob
        vm.expectRevert(IEpochBasedInflationaryVoteToken.VoteEpoch.selector);

        vm.prank(_alice);
        _vote.delegate(_bob);
    }

    function test_noTransfersDuringVotingEpoch() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        _warpToNextVoteEpoch();

        // alice attempts to transfer to bob
        vm.expectRevert(IEpochBasedInflationaryVoteToken.VoteEpoch.selector);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);
    }

    function test_usersVoteInflationUpgradeOnDelegation() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_carol);

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 1_200);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol); // 1200 * 1.2 = 1440

        assertEq(_vote.getVotes(_carol), 1_440);
        assertEq(_vote.balanceOf(_alice), 1_200);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_440);
    }

    function test_usersVoteInflationWorksWithTransfer() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _vote.transfer(_carol, 500);

        assertEq(_vote.balanceOf(_alice), 700);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 700);

        assertEq(_vote.balanceOf(_carol), 500);
        assertEq(_vote.getVotes(_carol), 500);
    }

    function test_votingPowerForDelegates() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);
        _vote.mint(_bob, 900);
        _vote.mint(_carol, 800);

        vm.prank(_alice);
        _vote.delegate(_carol);

        vm.prank(_bob);
        _vote.delegate(_carol);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 900);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 800);
        assertEq(_vote.getVotes(_carol), 2_700);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.balanceOf(_bob), 1_080);
        assertEq(_vote.balanceOf(_carol), 960);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_bob) + _vote.balanceOf(_carol));

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_bob) + _vote.balanceOf(_carol));

        vm.prank(_carol);
        _vote.transfer(_bob, 500);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_bob) + _vote.balanceOf(_carol));

        vm.prank(_bob);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_carol));
        assertEq(_vote.getVotes(_bob), _vote.balanceOf(_bob));
    }

    function test_usersVoteInflationForMultipleEpochsWithRedelegation() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);
        _vote.mint(_bob, 900);
        _vote.mint(_carol, 800);

        vm.prank(_alice);
        _vote.delegate(_carol);

        vm.prank(_bob);
        _vote.delegate(_carol);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol);

        assertEq(_vote.getVotes(_carol), 3_240);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.balanceOf(_bob), 900);
        assertEq(_vote.balanceOf(_carol), 800);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.balanceOf(_bob), 1_080);
        assertEq(_vote.balanceOf(_carol), 960);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_bob), 1_200);
        assertEq(_vote.getVotes(_carol), 2_040);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_carol); // carol votes, but bob doesn't

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 1_200);
        assertEq(_vote.getVotes(_carol), 2_448);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.balanceOf(_bob), 1_080);
        assertEq(_vote.balanceOf(_carol), 960);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.balanceOf(_bob), 1_296);
        assertEq(_vote.balanceOf(_carol), 1_152);
    }

    function test_usersVoteInflationForMultipleEpochsWithTransfers() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        vm.prank(_alice);
        _vote.transfer(_carol, 400);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 600);
        assertEq(_vote.getVotes(_carol), 400);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_alice);
        _vote.markParticipation(_bob);
        _vote.markParticipation(_carol);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 720);
        assertEq(_vote.getVotes(_carol), 480);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), 600);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 400);

        // attempt to transfer fails
        vm.expectRevert(IEpochBasedInflationaryVoteToken.VoteEpoch.selector);

        vm.prank(_alice);
        _vote.transfer(_bob, 200);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), 720);
        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.balanceOf(_carol), 480);

        vm.prank(_alice);
        _vote.transfer(_bob, 720);

        vm.prank(_carol);
        _vote.transfer(_bob, 480);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 1_200);
        assertEq(_vote.getVotes(_carol), 0);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), 1_200);
        assertEq(_vote.balanceOf(_carol), 0);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        // Balances do not inflate until the end of the epoch
        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), 1_200);
        assertEq(_vote.balanceOf(_carol), 0);

        _warpToNextTransferEpoch();

        // Balances inflate upon the end of the epoch
        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), 1_440);
        assertEq(_vote.balanceOf(_carol), 0);
    }

    function test_sync_futureEpoch() external {
        uint16 currentEpoch_ = _currentEpoch();

        vm.expectRevert(
            abi.encodeWithSelector(
                IEpochBasedInflationaryVoteToken.FutureEpoch.selector,
                currentEpoch_,
                currentEpoch_ + 1
            )
        );

        _vote.sync(_alice, currentEpoch_ + 1);
    }

    function test_sync() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        uint16 lastBalanceUpdate_ = _currentEpoch();

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _warpToNextTransferEpoch();

        assertEq(_vote.getBalanceSnapStartingEpoch(_alice, 0), lastBalanceUpdate_);

        uint16 currentEpoch_ = _currentEpoch();

        vm.expectEmit();
        emit IEpochBasedInflationaryVoteToken.Sync(_alice, currentEpoch_);

        _vote.sync(_alice, currentEpoch_);

        assertEq(_vote.getBalanceSnapStartingEpoch(_alice, 1), currentEpoch_);
    }

    function test_scenario1() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // (1000 * 1.2) * 1.2 = 1440

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_alice);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_alice); // ((1000 * 1.2) * 1.2) * 1.2 = 1728
        _vote.markParticipation(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob);

        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // (((1000 * 1.2) * 1.2) * 1.2) * 1.2 = 2073

        _warpToNextVoteEpoch();

        _vote.markParticipation(_bob); // ((((1000 * 1.2) * 1.2) * 1.2) * 1.2) * 1.2 = 2487

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 2_487);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 2_487);
    }
}
