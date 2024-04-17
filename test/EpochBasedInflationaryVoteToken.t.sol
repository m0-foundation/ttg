// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { IEpochBasedVoteToken } from "../src/abstract/interfaces/IEpochBasedVoteToken.sol";
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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        _vote.mint(_alice, 1_000);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        _vote.mint(_alice, 1_000);

        assertEq(_vote.delegates(_alice), _alice);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.delegates(_alice), _bob);

        assertEq(_vote.balanceOf(_alice), 1_000);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

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
        uint256 balance_ = 1_000;

        _warpToNextTransferEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, balance_);

        _vote.mint(_alice, balance_);

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), balance_);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), balance_);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 200);

        _vote.markParticipation(_alice);

        uint256 balanceWithInflation_ = balance_ + _vote.getInflation(balance_); // 1_200

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), balanceWithInflation_);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), balanceWithInflation_);

        uint256 transferAmount_ = 500;
        uint256 aliceBalanceAfterTransfer_ = balanceWithInflation_ - transferAmount_; // 700

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _vote.transfer(_bob, transferAmount_);

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), aliceBalanceAfterTransfer_);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), aliceBalanceAfterTransfer_);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);
    }

    function test_inflationFromVotingPowerInPreviousEpoch_delegated() external {
        uint256 balance_ = 1_000;

        _warpToNextTransferEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, balance_);

        _vote.mint(_alice, balance_);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balance_);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balance_);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 200);

        _vote.markParticipation(_bob);

        uint256 balanceWithInflation_ = balance_ + _vote.getInflation(balance_); // 1_200

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balanceWithInflation_);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balanceWithInflation_);

        uint256 transferAmount_ = 500;
        uint256 aliceBalanceAfterTransfer_ = balanceWithInflation_ - transferAmount_; // 700

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _vote.transfer(_bob, transferAmount_);

        vm.prank(_alice);
        _vote.delegate(_alice);

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), aliceBalanceAfterTransfer_);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), aliceBalanceAfterTransfer_);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);
    }

    function test_inflationFromVotingPowerInPreviousEpochs_multipleDelegatees() external {
        uint256 balance_ = 1_000;

        _warpToNextTransferEpoch();

        _vote.mint(_alice, balance_);

        vm.prank(_alice);
        _vote.delegate(_bob); // First delegation to Bob in first transfer epoch

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balance_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 0);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balance_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 0);

        // Bob votes in the first voting epoch
        _vote.markParticipation(_bob);

        uint256 balanceWithInflation_ = balance_ + _vote.getInflation(balance_); // 1_200

        assertEq(_vote.balanceOf(_alice), balance_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balanceWithInflation_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 0);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), balanceWithInflation_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 0);

        vm.prank(_alice);
        _vote.delegate(_carol); // Second delegation to Carol in second transfer epoch

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), balanceWithInflation_);

        _warpToNextVoteEpoch();

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), balanceWithInflation_);

        // Carol votes in the second voting epoch
        _vote.markParticipation(_carol);

        uint256 previousBalanceWithInflation_ = balanceWithInflation_;
        balanceWithInflation_ = balanceWithInflation_ + _vote.getInflation(balanceWithInflation_); // 1_440

        assertEq(_vote.balanceOf(_alice), previousBalanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), balanceWithInflation_);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), balanceWithInflation_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), balanceWithInflation_);

        uint256 transferAmount_ = 500;
        uint256 aliceBalanceAfterTransfer_ = balanceWithInflation_ - transferAmount_; // 940

        vm.prank(_alice);
        _vote.transfer(_bob, transferAmount_); // Alice transfers 500 tokens to Bob in the third transfer epoch

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), aliceBalanceAfterTransfer_);

        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();
        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), aliceBalanceAfterTransfer_);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), transferAmount_);
        assertEq(_vote.getVotes(_bob), transferAmount_);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), aliceBalanceAfterTransfer_);
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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 200);

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _warpToNextTransferEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.prank(_alice);
        _vote.delegate(_carol);

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.getVotes(_alice), 0);

        assertEq(_vote.balanceOf(_bob), 0);
        assertEq(_vote.getVotes(_bob), 0);

        assertEq(_vote.balanceOf(_carol), 0);
        assertEq(_vote.getVotes(_carol), 1_200);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 240);

        _vote.markParticipation(_carol); // 1200 * 1.2 = 1440

        assertEq(_vote.getVotes(_carol), 1_440);
        assertEq(_vote.balanceOf(_alice), 1_200);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_440);
    }

    function test_usersVoteInflationWorksWithTransfer() external {
        _warpToNextTransferEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 200);

        _vote.markParticipation(_bob); // 1000 * 1.2 = 1200

        _warpToNextTransferEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _carol, 500);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 540);

        _vote.markParticipation(_carol);

        _warpToNextTransferEpoch();

        assertEq(_vote.balanceOf(_alice), 1_200);
        assertEq(_vote.balanceOf(_bob), 1_080);
        assertEq(_vote.balanceOf(_carol), 960);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_bob) + _vote.balanceOf(_carol));

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _bob, 180);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _vote.transfer(_bob, 500);

        assertEq(_vote.getVotes(_carol), _vote.balanceOf(_alice) + _vote.balanceOf(_bob) + _vote.balanceOf(_carol));

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _carol, 160);

        vm.expectEmit();
        emit IERC20.Transfer(_carol, _bob, 500);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 540);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 200);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_bob), 1_200);
        assertEq(_vote.getVotes(_carol), 2_040);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _carol, 160);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 408);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        _vote.mint(_alice, 1_000);

        vm.prank(_alice);
        _vote.delegate(_bob);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _carol, 400);

        vm.prank(_alice);
        _vote.transfer(_carol, 400);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 600);
        assertEq(_vote.getVotes(_carol), 400);

        _warpToNextVoteEpoch();

        _vote.markParticipation(_alice);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 120);

        _vote.markParticipation(_bob);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 80);

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

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 120);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 720);

        vm.prank(_alice);
        _vote.transfer(_bob, 720);

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _carol, 80);

        vm.expectEmit();
        emit IERC20.Transfer(_carol, _bob, 480);

        vm.prank(_carol);
        _vote.transfer(_bob, 480);

        assertEq(_vote.getVotes(_alice), 0);
        assertEq(_vote.getVotes(_bob), 1_200);
        assertEq(_vote.getVotes(_carol), 0);

        assertEq(_vote.balanceOf(_alice), 0);
        assertEq(_vote.balanceOf(_bob), 1_200);
        assertEq(_vote.balanceOf(_carol), 0);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 240);

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

    function test_sync() external {
        _warpToNextTransferEpoch();

        _vote.mint(_alice, 1_000);

        uint16 lastBalanceUpdate_ = _currentEpoch();

        vm.prank(_alice);
        _vote.delegate(_bob);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 200);

        _vote.markParticipation(_bob);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 240);

        _vote.markParticipation(_bob);

        _warpToNextVoteEpoch();

        vm.expectEmit();
        emit IERC20.Transfer(address(0), address(_vote), 288);

        _vote.markParticipation(_bob);

        _warpToNextTransferEpoch();

        assertEq(_vote.getBalanceSnapStartingEpoch(_alice, 0), lastBalanceUpdate_);

        vm.expectEmit();
        emit IERC20.Transfer(address(_vote), _alice, 728);

        vm.expectEmit();
        emit IEpochBasedInflationaryVoteToken.Sync(_alice);

        _vote.sync(_alice);

        assertEq(_vote.getBalanceSnapStartingEpoch(_alice, 1), _currentEpoch());
    }

    function test_getLastSync() external {
        _vote.pushBalance(_alice, 2, 50);
        _vote.pushBalance(_alice, 4, 12);
        _vote.pushBalance(_alice, 9, 93);

        assertEq(_vote.getLastSync(_alice, 1), 0);
        assertEq(_vote.getLastSync(_alice, 2), 2);
        assertEq(_vote.getLastSync(_alice, 3), 2);
        assertEq(_vote.getLastSync(_alice, 4), 4);
        assertEq(_vote.getLastSync(_alice, 5), 4);
        assertEq(_vote.getLastSync(_alice, 6), 4);
        assertEq(_vote.getLastSync(_alice, 7), 4);
        assertEq(_vote.getLastSync(_alice, 8), 4);
        assertEq(_vote.getLastSync(_alice, 9), 9);
        assertEq(_vote.getLastSync(_alice, 10), 9);
    }

    function test_getLastSync_zeroEpoch() external {
        vm.expectRevert(IEpochBasedVoteToken.EpochZero.selector);
        _vote.getLastSync(_alice, 0);
    }

    function test_hasParticipatedAt() external {
        _vote.pushParticipation(_alice, 2);
        _vote.pushParticipation(_alice, 4);
        _vote.pushParticipation(_alice, 9);

        assertEq(_vote.hasParticipatedAt(_alice, 1), false);
        assertEq(_vote.hasParticipatedAt(_alice, 2), true);
        assertEq(_vote.hasParticipatedAt(_alice, 3), false);
        assertEq(_vote.hasParticipatedAt(_alice, 4), true);
        assertEq(_vote.hasParticipatedAt(_alice, 5), false);
        assertEq(_vote.hasParticipatedAt(_alice, 6), false);
        assertEq(_vote.hasParticipatedAt(_alice, 7), false);
        assertEq(_vote.hasParticipatedAt(_alice, 8), false);
        assertEq(_vote.hasParticipatedAt(_alice, 9), true);
        assertEq(_vote.hasParticipatedAt(_alice, 10), false);
    }

    function test_hasParticipatedAt_zeroEpoch() external {
        vm.expectRevert(IEpochBasedVoteToken.EpochZero.selector);
        _vote.hasParticipatedAt(_alice, 0);
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
