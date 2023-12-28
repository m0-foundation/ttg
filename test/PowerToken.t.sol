// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { PureEpochs } from "../src/libs/PureEpochs.sol";

import { IEpochBasedInflationaryVoteToken } from "../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "../src/interfaces/IPowerToken.sol";

import { PowerBootstrapToken } from "../src/PowerBootstrapToken.sol";

import { MockBootstrapToken, MockCashToken } from "./utils/Mocks.sol";
import { PowerTokenHarness } from "./utils/PowerTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: Create and use a harness functions instead of calling functions unrelated to each test.

contract PowerTokenTests is TestUtils {
    address internal _account = makeAddr("account");
    address internal _standardGovernor = makeAddr("standardGovernor");
    address internal _vault = makeAddr("vault");

    address[] internal _initialAccounts = [
        makeAddr("account1"),
        makeAddr("account2"),
        makeAddr("account3"),
        makeAddr("account4"),
        makeAddr("account5")
    ];

    uint256[] internal _initialAmounts = [
        1_000_000 * 1e6,
        2_000_000 * 1e6,
        3_000_000 * 1e6,
        4_000_000 * 1e6,
        5_000_000 * 1e6
    ];

    PowerTokenHarness internal _powerToken;
    MockBootstrapToken internal _bootstrapToken;
    MockCashToken internal _cashToken;

    function setUp() external {
        _cashToken = new MockCashToken();
        _bootstrapToken = new MockBootstrapToken();

        _bootstrapToken.setTotalSupply(15_000_000 * 1e6);

        for (uint256 index_; index_ < _initialAccounts.length; ++index_) {
            _bootstrapToken.setBalance(_initialAccounts[index_], _initialAmounts[index_]);
        }

        _powerToken = new PowerTokenHarness(address(_bootstrapToken), _standardGovernor, address(_cashToken), _vault);
    }

    function test_initialState() external {
        assertEq(_powerToken.bootstrapToken(), address(_bootstrapToken));
        assertEq(_powerToken.cashToken(), address(_cashToken));
        assertEq(_powerToken.standardGovernor(), _standardGovernor);
        assertEq(_powerToken.vault(), _vault);
        assertEq(_powerToken.bootstrapEpoch(), PureEpochs.currentEpoch() - 1);

        assertEq(_powerToken.nextCashTokenStartingEpoch(), 0);
        assertEq(_powerToken.internalCashToken(), address(0));
        assertEq(_powerToken.internalNextCashToken(), address(_cashToken));

        for (uint256 index_; index_ < _initialAccounts.length; ++index_) {
            assertEq(
                _powerToken.balanceOf(_initialAccounts[index_]),
                ((_initialAmounts[index_] * _powerToken.INITIAL_SUPPLY()) / (15_000_000 * 1e6))
            );
        }
    }

    function test_constructor_invalidBootstrapTokenAddress() external {
        vm.expectRevert(IPowerToken.InvalidBootstrapTokenAddress.selector);
        new PowerTokenHarness(address(0), _standardGovernor, address(_cashToken), _vault);
    }

    function test_constructor_invalidStandardGovernorAddress() external {
        vm.expectRevert(IPowerToken.InvalidStandardGovernorAddress.selector);
        new PowerTokenHarness(address(_bootstrapToken), address(0), address(_cashToken), _vault);
    }

    function test_constructor_invalidCashTokenAddress() external {
        vm.expectRevert(IPowerToken.InvalidCashTokenAddress.selector);
        new PowerTokenHarness(address(_bootstrapToken), _standardGovernor, address(0), _vault);
    }

    function test_constructor_invalidVaultAddress() external {
        vm.expectRevert(IPowerToken.InvalidVaultAddress.selector);
        new PowerTokenHarness(address(_bootstrapToken), _standardGovernor, address(_cashToken), address(0));
    }

    function test_getCost() external {
        vm.skip(true); // Will be fixed ot be generic when round up/down is implemented.

        uint256 halfAnAuctionPeriod_ = PureEpochs._EPOCH_PERIOD / 200; // _powerToken._AUCTION_PERIODS = 100;

        _warpToNextTransferEpoch();

        uint256 totalSupply_ = _powerToken.pastTotalSupply(PureEpochs.currentEpoch() - 1);
        uint256 onePercentOfTotalSupply_ = totalSupply_ / 100;
        uint256 oneBasisPointOfTotalSupply_ = onePercentOfTotalSupply_ / 100;

        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 99));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 99));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 99));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 99)) / 100_000);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), (1 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(1), uint256(1 * ((1 << 99) + (1 << 98))) / 200_000);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 98));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 98));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 98));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 98)) / 100_000);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), (1 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(1), uint256(1 * ((1 << 98) + (1 << 97))) / 200_000);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 97));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 97));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 97));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 97)) / 100_000);

        _jumpSeconds(192 * halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 1));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 1));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 1));
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 1) + (1 << 0))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 1) + (1 << 0))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1);
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 0));
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 5_000 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 50 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(halfAnAuctionPeriod_ / 2);
        assertEq(_powerToken.getCost(totalSupply_), 2_500 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 25 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(halfAnAuctionPeriod_ / 4);
        assertEq(_powerToken.getCost(totalSupply_), 1_250 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 12 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds((halfAnAuctionPeriod_ / 4) - 1);
        assertEq(_powerToken.getCost(totalSupply_), 0);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpSeconds(1); // At end of auction.
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 99));
    }

    function test_amountToAuction() external {
        uint256 inflation_;

        assertEq(_powerToken.amountToAuction(), inflation_);

        for (uint256 index_; index_ < 10; ++index_) {
            _warpToNextTransferEpoch();

            // During transfer epochs, the next voting epoch is the current epoch + 1.
            vm.prank(_standardGovernor);
            _powerToken.markNextVotingEpochAsActive();

            assertEq(_powerToken.amountToAuction(), inflation_);

            _warpToNextVoteEpoch();

            inflation_ = inflation_ + (_powerToken.INITIAL_SUPPLY() + inflation_) / 10;

            // During voting epochs, the next voting epoch is the current epoch + 2.
            vm.prank(_standardGovernor);
            _powerToken.markNextVotingEpochAsActive();

            assertEq(_powerToken.amountToAuction(), 0);
        }
    }

    function test_buy_insufficientAuctionSupply() external {
        vm.expectRevert(abi.encodeWithSelector(IPowerToken.InsufficientAuctionSupply.selector, 0, 1));
        _powerToken.buy(1, 1, _account);
    }

    function test_buy_notInVotePeriod() external {
        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + 1);

        _warpToNextVoteEpoch();

        vm.expectRevert(abi.encodeWithSelector(IPowerToken.InsufficientAuctionSupply.selector, 0, 1));
        vm.prank(_account);
        _powerToken.buy(1, 1, _account);
    }

    function test_buy_transferFromFailed() external {
        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + 1);

        _warpToNextTransferEpoch();

        _cashToken.setTransferFromFail(true);

        vm.expectRevert(IPowerToken.TransferFromFailed.selector);
        _powerToken.buy(1, 1, _account);
    }

    function test_buy() external {
        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + _powerToken.totalSupply() / 10);

        _warpToNextTransferEpoch();

        uint256 oneBasisPointOfTotalSupply_ = _powerToken.pastTotalSupply(PureEpochs.currentEpoch() - 1) / 10_000;

        vm.expectCall(
            address(_cashToken),
            abi.encodeWithSelector(MockCashToken.transferFrom.selector, _account, _vault, 1 * (1 << 99))
        );
        vm.prank(_account);
        _powerToken.buy(0, oneBasisPointOfTotalSupply_, _account);

        assertEq(_powerToken.balanceOf(_account), oneBasisPointOfTotalSupply_);
    }

    function test_setNextCashToken_NotStandardGovernor() external {
        vm.expectRevert(IPowerToken.NotStandardGovernor.selector);
        _powerToken.setNextCashToken(address(0));
    }

    function test_setNextCashToken_afterNextCashTokenStartingEpoch() external {
        address newCashToken_ = makeAddr("newCashToken");

        vm.prank(_standardGovernor);
        _powerToken.setNextCashToken(newCashToken_);

        assertEq(_powerToken.nextCashTokenStartingEpoch(), PureEpochs.currentEpoch() + 1);
        assertEq(_powerToken.internalCashToken(), address(_cashToken));
        assertEq(_powerToken.internalNextCashToken(), newCashToken_);

        assertEq(_powerToken.cashToken(), address(_cashToken));

        _warpToNextEpoch();

        assertEq(_powerToken.cashToken(), address(newCashToken_));
    }

    function test_setNextCashToken_beforeNextCashTokenStartingEpoch() external {
        address newCashToken_ = makeAddr("newCashToken");

        uint256 nextCashTokenStartingEpoch_ = PureEpochs.currentEpoch() + 1;

        _powerToken.setNextCashTokenStartingEpoch(nextCashTokenStartingEpoch_);
        _powerToken.setInternalCashToken(address(_cashToken));
        _powerToken.setInternalNextCashToken(makeAddr("someCashToken"));

        vm.prank(_standardGovernor);
        _powerToken.setNextCashToken(newCashToken_);

        assertEq(_powerToken.nextCashTokenStartingEpoch(), nextCashTokenStartingEpoch_); // Unchanged.
        assertEq(_powerToken.internalCashToken(), address(_cashToken)); // Unchanged.
        assertEq(_powerToken.internalNextCashToken(), newCashToken_);

        assertEq(_powerToken.cashToken(), address(_cashToken));

        _warpToNextEpoch();

        assertEq(_powerToken.cashToken(), address(newCashToken_));
    }

    function test_notAffectedByBootstrapTokenAfterBootstrapEpoch() external {
        PowerBootstrapToken bootstrapToken_ = new PowerBootstrapToken(_initialAccounts, _initialAmounts);

        PowerTokenHarness powerToken1_ = new PowerTokenHarness(
            address(bootstrapToken_),
            makeAddr("standard"),
            makeAddr("cash"),
            makeAddr("vault")
        );

        _warpToNextTransferEpoch();

        // Do some no-op transfers.
        for (uint256 i; i < 5; ++i) {
            vm.prank(_initialAccounts[i]);
            powerToken1_.transfer(_initialAccounts[(i + 1) % 5], 0);
        }

        _warpToNextTransferEpoch();

        PowerTokenHarness powerToken2_ = new PowerTokenHarness(
            address(powerToken1_),
            makeAddr("standard"),
            makeAddr("cash"),
            makeAddr("vault")
        );

        _warpToNextTransferEpoch();

        // Sync balance from `powerToken1_` for `_initialAccounts[1]` and `_initialAccounts[1]`.
        vm.prank(_initialAccounts[1]);
        powerToken2_.transfer(_initialAccounts[2], 0);

        _warpToNextTransferEpoch();

        // Transfer all old power to first account.
        for (uint256 i = 1; i < 5; ++i) {
            uint256 balance = powerToken1_.balanceOf(_initialAccounts[i]);

            vm.prank(_initialAccounts[i]);
            powerToken1_.transfer(_initialAccounts[0], balance);
        }

        _warpToNextTransferEpoch();

        uint256 clock_ = powerToken2_.clock();

        assertEq(powerToken2_.pastTotalSupply(clock_ - 1), 1_000_000_000);

        uint256 b1 = powerToken2_.pastBalanceOf(_initialAccounts[0], clock_ - 1);
        uint256 b2 = powerToken2_.pastBalanceOf(_initialAccounts[1], clock_ - 1);
        uint256 b3 = powerToken2_.pastBalanceOf(_initialAccounts[2], clock_ - 1);
        uint256 b4 = powerToken2_.pastBalanceOf(_initialAccounts[3], clock_ - 1);
        uint256 b5 = powerToken2_.pastBalanceOf(_initialAccounts[4], clock_ - 1);

        uint256 v1 = powerToken2_.getPastVotes(_initialAccounts[0], clock_ - 1);
        uint256 v2 = powerToken2_.getPastVotes(_initialAccounts[1], clock_ - 1);
        uint256 v3 = powerToken2_.getPastVotes(_initialAccounts[2], clock_ - 1);
        uint256 v4 = powerToken2_.getPastVotes(_initialAccounts[3], clock_ - 1);
        uint256 v5 = powerToken2_.getPastVotes(_initialAccounts[4], clock_ - 1);

        assertEq(b1, 66_666_666);
        assertEq(b2, 133_333_333);
        assertEq(b3, 200_000_000);
        assertEq(b4, 266_666_666);
        assertEq(b5, 333_333_333);

        assertEq(v1, 66_666_666);
        assertEq(v2, 133_333_333);
        assertEq(v3, 200_000_000);
        assertEq(v4, 266_666_666);
        assertEq(v5, 333_333_333);

        assertLe(b1 + b2 + b3 + b4 + b5, 1_000_000_000);
        assertLe(v1 + v2 + v3 + v4 + v5, 1_000_000_000);
    }
}
