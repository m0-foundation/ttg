// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { PureEpochs } from "../src/libs/PureEpochs.sol";

import { IEpochBasedInflationaryVoteToken } from "../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "../src/interfaces/IPowerToken.sol";

import { MockBootstrapToken, MockCashToken } from "./utils/Mocks.sol";
import { PowerTokenHarness } from "./utils/PowerTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: Create amd use a harness functions instead of calling functions unrelated to each test.

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

    function test_getCost() external {
        vm.skip(true);

        uint256 halfAnAuctionPeriod_ = PureEpochs._EPOCH_PERIOD / 200; // _powerToken._AUCTION_PERIODS = 100;

        _goToNextTransferEpoch();

        uint256 totalSupply_ = _powerToken.pastTotalSupply(PureEpochs.currentEpoch() - 1);
        uint256 onePercentOfTotalSupply_ = totalSupply_ / 100;
        uint256 oneBasisPointOfTotalSupply_ = onePercentOfTotalSupply_ / 100;

        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 99));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 99));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 99));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 99)) / 100_000);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), (1 * ((1 << 99) + (1 << 98))) / 2);
        assertEq(_powerToken.getCost(1), uint256(1 * ((1 << 99) + (1 << 98))) / 200_000);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 98));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 98));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 98));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 98)) / 100_000);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), (1 * ((1 << 98) + (1 << 97))) / 2);
        assertEq(_powerToken.getCost(1), uint256(1 * ((1 << 98) + (1 << 97))) / 200_000);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 97));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 97));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 97));
        assertEq(_powerToken.getCost(1), uint256(1 * (1 << 97)) / 100_000);

        _jumpBlocks(192 * halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 1));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 1));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 1));
        assertEq(_powerToken.getCost(1), 0);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), (10_000 * ((1 << 1) + (1 << 0))) / 2);
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), (100 * ((1 << 1) + (1 << 0))) / 2);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1);
        assertEq(_powerToken.getCost(1), 0);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 100 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 1 * (1 << 0));
        assertEq(_powerToken.getCost(1), 0);

        _jumpBlocks(halfAnAuctionPeriod_);
        assertEq(_powerToken.getCost(totalSupply_), 5_000 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 50 * (1 << 0));
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpBlocks(halfAnAuctionPeriod_ - 1);
        assertEq(_powerToken.getCost(totalSupply_), 9 * (1 << 0));
        assertEq(_powerToken.getCost(onePercentOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(oneBasisPointOfTotalSupply_), 0);
        assertEq(_powerToken.getCost(1), 0);

        _jumpBlocks(1); // At end of auction.
        assertEq(_powerToken.getCost(totalSupply_), 10_000 * (1 << 99));
    }

    function test_amountToAuction() external {
        uint256 inflation_;

        assertEq(_powerToken.amountToAuction(), inflation_);

        for (uint256 index_; index_ < 10; ++index_) {
            _goToNextTransferEpoch();

            // During transfer epochs, the next voting epoch is the current epoch + 1.
            vm.prank(_standardGovernor);
            _powerToken.markNextVotingEpochAsActive();

            assertEq(_powerToken.amountToAuction(), inflation_);

            _goToNextVoteEpoch();

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

        _goToNextVoteEpoch();

        vm.expectRevert(abi.encodeWithSelector(IPowerToken.InsufficientAuctionSupply.selector, 0, 1));
        vm.prank(_account);
        _powerToken.buy(1, 1, _account);
    }

    function test_buy_transferFromFailed() external {
        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + 1);

        _goToNextTransferEpoch();

        _cashToken.setTransferFromFail(true);

        vm.expectRevert(IPowerToken.TransferFromFailed.selector);
        _powerToken.buy(1, 1, _account);
    }

    function test_buy() external {
        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + _powerToken.totalSupply() / 10);

        _goToNextTransferEpoch();

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

        _goToNextEpoch();

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

        _goToNextEpoch();

        assertEq(_powerToken.cashToken(), address(newCashToken_));
    }
}
