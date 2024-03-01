// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../lib/forge-std/src/Test.sol";

import { PureEpochs } from "../../src/libs/PureEpochs.sol";

import { IEpochBasedInflationaryVoteToken } from "../../src/abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

import { IPowerToken } from "../../src/interfaces/IPowerToken.sol";

import { PowerBootstrapToken } from "../../src/PowerBootstrapToken.sol";

import { MockBootstrapToken, MockCashToken } from "./../utils/Mocks.sol";
import { PowerTokenHarness } from "./../utils/PowerTokenHarness.sol";
import { TestUtils } from "./../utils/TestUtils.sol";

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

    function testFuzz_amountToAuction(uint240 targetSupply_) external {
        uint256 inflation_;

        assertEq(_powerToken.amountToAuction(), inflation_);

        _powerToken.setInternalNextTargetSupply(targetSupply_);

        _warpToNextTransferEpoch();

        uint240 totalSupply_ = uint240(_powerToken.pastTotalSupply(PureEpochs.currentEpoch() - 1));

        if (totalSupply_ <= targetSupply_) {
            assertEq(_powerToken.amountToAuction(), targetSupply_ - totalSupply_);
        } else {
            assertEq(_powerToken.amountToAuction(), 0);
        }
    }

    function testFuzz_buy(uint240 minAmount_, uint240 maxAmount_, uint40 auctionPeriod) external {
        minAmount_ = uint240(bound(minAmount_, 1, type(uint240).max));
        maxAmount_ = uint240(bound(maxAmount_, 1, type(uint240).max));
        auctionPeriod = uint40(bound(auctionPeriod, 0, PureEpochs._EPOCH_PERIOD));
        vm.assume(maxAmount_ > minAmount_);

        vm.expectRevert(abi.encodeWithSelector(IPowerToken.InsufficientAuctionSupply.selector, 0, minAmount_));
        vm.prank(_account);
        _powerToken.buy(minAmount_, maxAmount_, _account, _currentEpoch());

        _powerToken.setInternalNextTargetSupply(_powerToken.totalSupply() + _powerToken.totalSupply() / 10); //@elcid 10% increase

        _warpToNextTransferEpoch();
        _jumpSeconds(auctionPeriod);

        uint240 amountToAuction_ = _powerToken.amountToAuction();
        uint240 amount_ = amountToAuction_ > maxAmount_ ? maxAmount_ : amountToAuction_;

        console2.log(amountToAuction_);

        if (amount_ < minAmount_) {
            vm.expectRevert(
                abi.encodeWithSelector(IPowerToken.InsufficientAuctionSupply.selector, amountToAuction_, minAmount_)
            );
            vm.prank(_account);
            _powerToken.buy(minAmount_, maxAmount_, _account, _currentEpoch());
        } else {
            vm.prank(_account);
            _powerToken.buy(minAmount_, maxAmount_, _account, _currentEpoch());

            assertEq(_powerToken.balanceOf(_account), amount_);
            assertTrue(_powerToken.getCost(amount_) != 0); //no rounding down issues
        }
    }
}
