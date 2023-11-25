// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { PureEpochs } from "../src/libs/PureEpochs.sol";

import { IEpochBasedInflationaryVoteToken } from "../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "../src/interfaces/IPowerToken.sol";

import { MockBootstrapToken, MockCashToken } from "./utils/Mocks.sol";
import { PowerTokenHarness } from "./utils/PowerTokenHarness.sol";
import { TestUtils } from "./utils/TestUtils.sol";

// TODO: Create amd use a harness functions instead of calling functions unrelated to each test.

contract PowerTokenTests is TestUtils {
    address internal _governor = makeAddr("governor");
    address internal _account = makeAddr("account");
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

        _powerToken = new PowerTokenHarness(_governor, address(_cashToken), _vault, address(_bootstrapToken));
    }

    function test_initialState() external {
        assertEq(_powerToken.bootstrapToken(), address(_bootstrapToken));
        assertEq(_powerToken.cashToken(), address(_cashToken));
        assertEq(_powerToken.governor(), _governor);
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
        uint256 halfAnAuctionPeriod_ = PureEpochs._EPOCH_PERIOD / 200; // _powerToken._AUCTION_PERIODS = 100;

        _goToNextTransferEpoch();

        uint256 totalSupply_ = _powerToken.totalSupplyAt(PureEpochs.currentEpoch() - 1);
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
        assertEq(_powerToken.amountToAuction(), 0);

        vm.prank(_governor);
        _powerToken.markEpochActive();

        assertEq(_powerToken.amountToAuction(), 0);

        _goToNextTransferEpoch();
        uint256 inflation_ = _powerToken.INITIAL_SUPPLY() / 10;
        assertEq(_powerToken.amountToAuction(), inflation_);

        _goToNextVoteEpoch();

        vm.prank(_governor);
        _powerToken.markEpochActive();

        assertEq(_powerToken.amountToAuction(), inflation_);

        _goToNextTransferEpoch();
        assertEq(_powerToken.amountToAuction(), inflation_ + (_powerToken.INITIAL_SUPPLY() + inflation_) / 10);
    }

    function test_buy_insufficientAuctionSupply() external {
        vm.expectRevert(IPowerToken.InsufficientAuctionSupply.selector);
        _powerToken.buy(1, _account);
    }

    function test_buy_notInVotePeriod() external {
        vm.prank(_governor);
        _powerToken.markEpochActive();

        _goToNextVoteEpoch();

        _cashToken.setTransferFromSuccess(true);

        vm.expectRevert(IEpochBasedInflationaryVoteToken.VoteEpoch.selector); // TODO: check if can use IPowerToken here
        vm.prank(_account);
        _powerToken.buy(1, _account);
    }

    function test_buy_transferFromFailed() external {
        vm.prank(_governor);
        _powerToken.markEpochActive();

        _goToNextTransferEpoch();

        vm.expectRevert(IPowerToken.TransferFromFailed.selector);
        _powerToken.buy(1, _account);
    }

    function test_buy() external {
        vm.prank(_governor);
        _powerToken.markEpochActive();

        _goToNextTransferEpoch();

        _cashToken.setTransferFromSuccess(true);

        uint256 oneBasisPointOfTotalSupply_ = _powerToken.totalSupplyAt(PureEpochs.currentEpoch() - 1) / 10_000;

        vm.expectCall(
            address(_cashToken),
            abi.encodeWithSelector(MockCashToken.transferFrom.selector, _account, _vault, 1 * (1 << 99))
        );
        vm.prank(_account);
        _powerToken.buy(oneBasisPointOfTotalSupply_, _account);

        assertEq(_powerToken.balanceOf(_account), oneBasisPointOfTotalSupply_);
    }

    function test_setNextCashToken_notGovernor() external {
        vm.expectRevert(IPowerToken.NotGovernor.selector);
        _powerToken.setNextCashToken(address(0));
    }

    function test_setNextCashToken_afterNextCashTokenStartingEpoch() external {
        address newCashToken_ = makeAddr("newCashToken");

        vm.prank(_governor);
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

        vm.prank(_governor);
        _powerToken.setNextCashToken(newCashToken_);

        assertEq(_powerToken.nextCashTokenStartingEpoch(), nextCashTokenStartingEpoch_); // Unchanged.
        assertEq(_powerToken.internalCashToken(), address(_cashToken)); // Unchanged.
        assertEq(_powerToken.internalNextCashToken(), newCashToken_);

        assertEq(_powerToken.cashToken(), address(_cashToken));

        _goToNextEpoch();

        assertEq(_powerToken.cashToken(), address(newCashToken_));
    }
}
