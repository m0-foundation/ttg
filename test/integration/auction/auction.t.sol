// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { PureEpochs } from "../../../src/libs/PureEpochs.sol";

import { IntegrationBaseSetup, IBatchGovernor } from "../IntegrationBaseSetup.t.sol";

contract Auction_IntegrationTest is IntegrationBaseSetup {
    function test_auction_multipleEpochs() external {
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        ) = _getSetKeyProposeParams();

        vm.prank(_dave);
        uint256 proposalId1_ = _standardGovernor.propose(targets_, values_, callDatas_, description_);

        _warpToNextVoteEpoch();

        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId1_, noSupport_);

        vm.prank(_bob);
        _standardGovernor.castVote(proposalId1_, noSupport_);

        // Carol misses her inflation
        assertEq(_powerToken.amountToAuction(), 0); // nothing to auction yet

        _warpToNextEpoch();

        assertEq(_powerToken.amountToAuction(), 200); // carol inflation is up for auction

        _warpToNextTransferEpoch();

        assertEq(_powerToken.amountToAuction(), 200); // carol inflation is up for auction

        uint256 totalSupply_ = _powerToken.pastTotalSupply(_currentEpoch() - 1);

        assertEq(_powerToken.getCost(totalSupply_), (10_000 * (1 << 99)));

        uint256 daveCashBalanceBefore_ = _cashToken1.balanceOf(_dave);
        uint256 evePowerBalanceBefore_ = _powerToken.balanceOf(_eve);

        vm.prank(_dave);
        (uint256 purchaseAmount_, uint256 purchaseCost_) = _powerToken.buy(200, 200, _eve, _currentEpoch());

        uint256 daveCashBalanceAfter_ = _cashToken1.balanceOf(_dave);
        uint256 evePowerBalanceAfter_ = _powerToken.balanceOf(_eve);

        assertEq(purchaseAmount_, 200);
        assertEq(daveCashBalanceBefore_, daveCashBalanceAfter_ + purchaseCost_);
        assertEq(evePowerBalanceBefore_, evePowerBalanceAfter_ - purchaseAmount_);

        assertEq(purchaseAmount_, 200);
        assertEq(purchaseCost_, _powerToken.getCost(200));

        assertEq(_powerToken.amountToAuction(), 0); // nothing to auction after purchase

        // Last second of epoch
        _warpToTheEndOfTheEpoch(_currentEpoch());

        assertEq(
            _powerToken.getCost(totalSupply_),
            _divideUp(totalSupply_, (PureEpochs._EPOCH_PERIOD / 100) * totalSupply_)
        );

        vm.prank(_dave);
        uint256 proposalId2_ = _standardGovernor.propose(targets_, values_, callDatas_, description_);

        _warpToNextVoteEpoch();

        assertEq(_powerToken.getVotes(_eve), 200);

        vm.prank(_eve);
        uint256 eveWeight_ = _standardGovernor.castVote(proposalId2_, noSupport_);

        assertEq(eveWeight_, 200);
    }

    function _getSetKeyProposeParams()
        internal
        view
        returns (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_
        )
    {
        targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            _standardGovernor.setKey.selector,
            bytes32("TEST_KEY"),
            bytes32("TEST_VALUE")
        );

        description_ = "Set TEST_KEY to TEST_VALUE";
    }

    function _divideUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return ((x * 10_000) + y - 1) / y;
    }
}
