// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IBatchGovernor, IGovernor, IZeroGovernor } from "../IntegrationBaseSetup.t.sol";
import { Script, console2 } from "../../../../lib/forge-std/src/Script.sol";
import { PureEpochs } from "../../../src/libs/PureEpochs.sol";
import { IPowerToken } from "../../../src/interfaces/IPowerToken.sol";
import { IEmergencyGovernor } from "../../../src/interfaces/IEmergencyGovernor.sol";
import { IStandardGovernor } from "../../../src/interfaces/IStandardGovernor.sol";

contract SetCashToken_IntegrationTest is IntegrationBaseSetup {
    function test_initialBalancesVotes() external {
        assertEq(_zeroToken.balanceOf(_dave), 60_000_000e6);
        assertEq(_zeroToken.balanceOf(_eve), 30_000_000e6);
        assertEq(_zeroToken.balanceOf(_frank), 10_000_000e6);

        assertEq(_zeroToken.getVotes(_dave), 60_000_000e6); // self-delegated
        assertEq(_zeroToken.getVotes(_eve), 30_000_000e6); // self-delegated
        assertEq(_zeroToken.getVotes(_frank), 10_000_000e6); // self-delegated

        vm.prank(_dave);
        _zeroToken.delegate(address(0));

        assertEq(_zeroToken.getVotes(_dave), 60_000_000e6); // delegation to address(0) means self-delegation
        assertEq(_zeroToken.getVotes(address(0)), 0);

        assertEq(_zeroToken.pastBalanceOf(_dave, _currentEpoch() - 1), 0);
        assertEq(_zeroToken.getPastVotes(_dave, _currentEpoch() - 1), 0);

        assertEq(_powerToken.bootstrapEpoch(), _currentEpoch() - 1); // bootstrap epoch is the previous epoch

        // Verify POWER current balances and votes
        assertEq(_powerToken.balanceOf(_alice), 5500);
        assertEq(_powerToken.getVotes(_alice), 5500); // self-delegation

        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _powerToken.delegate(_bob);

        assertEq(_powerToken.balanceOf(_alice), 5500);
        assertEq(_powerToken.getVotes(_alice), 0); // self-delegation

        assertEq(_powerToken.balanceOf(_bob), 2500);
        assertEq(_powerToken.getVotes(_bob), 8000); // self-delegation + alice votes

        assertEq(_powerToken.balanceOf(_carol), 2000);
        assertEq(_powerToken.getVotes(_carol), 2000); // self-delegation

        // verify POWER past balances and votes
        assertEq(_powerToken.pastBalanceOf(_alice, _powerToken.bootstrapEpoch()), 5500);
        assertEq(_powerToken.getPastVotes(_alice, _powerToken.bootstrapEpoch()), 5500); // self-delegation

        assertEq(_powerToken.pastBalanceOf(_alice, _powerToken.bootstrapEpoch() - 1), 5500);
        assertEq(_powerToken.getPastVotes(_alice, _powerToken.bootstrapEpoch() - 1), 5500); // self-delegation

        assertEq(_powerToken.totalSupply(), _powerToken.INITIAL_SUPPLY()); // 10_000
        assertEq(_powerToken.pastTotalSupply(_powerToken.bootstrapEpoch()), _powerToken.INITIAL_SUPPLY()); // 10_000
        assertEq(_powerToken.pastTotalSupply(_powerToken.bootstrapEpoch() - 1), _powerToken.INITIAL_SUPPLY()); // 10_000

        console2.log("POWER token past total supply = ", _powerToken.pastTotalSupply(_powerToken.bootstrapEpoch()));

        console2.log("POWER token total supply = ", _powerToken.totalSupply());
        console2.log("ZERO token total supply = ", _zeroToken.totalSupply());
    }

    function test_inflation_auction_changeNextCashToken() external {
        assertEq(_zeroToken.balanceOf(_dave), 60_000_000e6);

        vm.prank(_dave);
        _zeroToken.transfer(_dave, 10_000_000e6);

        // inflation producing proposal
        (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_,
            uint256 proposalId1_
        ) = _createSetKeyProposal("key1", "value1", _dave);

        assertEq(uint256(_standardGovernor.state(proposalId1_)), 0); // Pending

        _warpToNextVoteEpoch();

        assertEq(uint256(_standardGovernor.state(proposalId1_)), 1); // Active

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);
        uint8 noSupport_ = uint8(IBatchGovernor.VoteType.No);

        vm.prank(_alice);
        assertEq(_standardGovernor.castVote(proposalId1_, yesSupport_), 5500);

        vm.prank(_bob);
        assertEq(_standardGovernor.castVote(proposalId1_, noSupport_), 2500);

        assertEq(uint256(_standardGovernor.state(proposalId1_)), 1); // Active

        assertEq(_zeroToken.balanceOf(_dave), 60_000_000e6);
        assertEq(_zeroToken.getVotes(_dave), 60_000_000e6); // self-delegated
        assertEq(_zeroToken.getPastVotes(_dave, _currentEpoch() - 1), 60_000_000e6);

        _changeCashToken(address(_cashToken2), 2 * _standardProposalFee);

        assertEq(_powerToken.cashToken(), address(_cashToken1)); // no change yet
        assertEq(_standardGovernor.cashToken(), address(_cashToken2));
        assertEq(_standardGovernor.proposalFee(), 2 * _standardProposalFee);

        _warpToNextEpoch();

        _changeCashToken(address(_cashToken1), 3 * _standardProposalFee);

        // Check balances and amount to auction
        assertEq(_powerToken.balanceOf(_alice), 5500 * 1.1);
        assertEq(_powerToken.balanceOf(_bob), 2500 * 1.1);
        assertEq(_powerToken.balanceOf(_carol), 2000); // carol missed her inflation
        assertEq(_powerToken.totalSupply(), (_powerToken.INITIAL_SUPPLY() * 11) / 10 - _powerToken.amountToAuction()); // 11_000
        assertEq(_powerToken.amountToAuction(), (_powerToken.balanceOf(_carol) * 10) / 100); // 10% of carol's balance

        assertEq(_powerToken.cashToken(), address(_cashToken2)); // no change yet
        assertEq(_standardGovernor.cashToken(), address(_cashToken1));
        assertEq(_standardGovernor.proposalFee(), 3 * _standardProposalFee);

        vm.warp(_getTimestampOfEpochStart(PureEpochs.currentEpoch()) + 12 days);

        uint256 cashBalanceBeforePurchase_ = _cashToken2.balanceOf(_dave);
        uint256 powerBalanceBeforePurchase_ = _powerToken.balanceOf(_dave);

        uint256 amountToAuction_ = _powerToken.amountToAuction();
        uint256 cost_ = _powerToken.getCost(amountToAuction_);

        vm.prank(_dave);
        _powerToken.buy(amountToAuction_, amountToAuction_, _dave, _currentEpoch());

        uint256 cashBalanceAfterPurchase_ = _cashToken2.balanceOf(_dave);
        uint256 powerBalanceAfterPurchase_ = _powerToken.balanceOf(_dave);

        assertEq(cashBalanceBeforePurchase_, cashBalanceAfterPurchase_ + cost_);
        assertEq(powerBalanceAfterPurchase_, powerBalanceBeforePurchase_ + amountToAuction_);

        uint256 cash1BalanceBeforeExecution = _cashToken1.balanceOf(_dave);
        _standardGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));
        uint256 cash1BalanceAfterExecution = _cashToken1.balanceOf(_dave);

        assertEq(cash1BalanceAfterExecution, cash1BalanceBeforeExecution + _standardProposalFee); // refund
    }

    function test_resetToZero_variousBalances() external {
        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _powerToken.delegate(_bob);

        vm.prank(_carol);
        _powerToken.delegate(_bob);

        // inflation producing proposal
        (, , , , uint256 proposalId1_) = _createSetKeyProposal("key1", "value1", _dave);

        _warpToNextVoteEpoch();

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        assertEq(_powerToken.getVotes(_bob), _powerToken.totalSupply());

        uint256 powerSupplyBeforeVoting_ = _powerToken.totalSupply();

        vm.prank(_bob);
        _standardGovernor.castVote(proposalId1_, yesSupport_);

        assertEq(_powerToken.getVotes(_bob), _powerToken.totalSupply());

        uint256 frankZeroBalance_ = _zeroToken.balanceOf(_frank);

        vm.prank(_frank);
        _zeroToken.transfer(_frank, frankZeroBalance_ / 2);

        uint256 eveZeroBalance_ = _zeroToken.balanceOf(_eve);

        vm.prank(_eve);
        _zeroToken.transfer(_frank, eveZeroBalance_);

        _warpToNextTransferEpoch();

        assertEq(_powerToken.getVotes(_bob), (powerSupplyBeforeVoting_ * 11) / 10);

        uint256 bobZeroBalanceBeforeReset_ = _zeroToken.balanceOf(_bob);

        vm.prank(_bob);
        _zeroToken.transfer(_alice, bobZeroBalanceBeforeReset_); // no effect on zero balance

        assertEq(_zeroToken.balanceOf(_alice), bobZeroBalanceBeforeReset_);

        _resetToZeroHolders();

        IPowerToken newPowerToken_ = IPowerToken(_registrar.powerToken());

        assertEq(_powerToken.getVotes(_bob), (powerSupplyBeforeVoting_ * 11) / 10);
        assertEq(_powerToken.getVotes(_alice), 0);
        assertEq(_powerToken.getVotes(_carol), 0);

        // assertEq(newPowerToken_.getVotes(_bob), 0);
        assertEq(newPowerToken_.getVotes(_alice), 0);
        assertEq(newPowerToken_.getVotes(_carol), 0);

        assertEq(newPowerToken_.totalSupply(), _powerToken.INITIAL_SUPPLY());

        uint256 currentEpoch_ = _currentEpoch();
        uint256 resetSnapshotEpoch_ = currentEpoch_ - 1;

        assertEq(
            newPowerToken_.getVotes(_bob),
            (_powerToken.INITIAL_SUPPLY() * _zeroToken.getPastVotes(_bob, resetSnapshotEpoch_)) /
                _zeroToken.pastTotalSupply(resetSnapshotEpoch_)
        );
        assertEq(
            newPowerToken_.getVotes(_dave),
            (_powerToken.INITIAL_SUPPLY() * _zeroToken.getPastVotes(_dave, resetSnapshotEpoch_)) /
                _zeroToken.pastTotalSupply(resetSnapshotEpoch_)
        );

        assertEq(
            newPowerToken_.getVotes(_frank),
            (_powerToken.INITIAL_SUPPLY() * _zeroToken.getPastVotes(_frank, resetSnapshotEpoch_)) /
                _zeroToken.pastTotalSupply(resetSnapshotEpoch_)
        );

        assertEq(newPowerToken_.getVotes(_eve), 0);

        assertEq(newPowerToken_.bootstrapEpoch(), currentEpoch_ - 1);

        assertEq(newPowerToken_.cashToken(), address(_cashToken1));
        assertEq(newPowerToken_.amountToAuction(), 0);

        assertEq(newPowerToken_.getVotes(_bob), newPowerToken_.balanceOf(_bob));
        assertEq(newPowerToken_.getVotes(_dave), newPowerToken_.balanceOf(_dave));
        assertEq(newPowerToken_.getVotes(_frank), newPowerToken_.balanceOf(_frank));
        assertEq(newPowerToken_.getVotes(_eve), newPowerToken_.balanceOf(_eve));

        _emergencyGovernor = IEmergencyGovernor(_registrar.emergencyGovernor());
        _standardGovernor = IStandardGovernor(_registrar.standardGovernor());

        vm.prank(_frank);
        newPowerToken_.delegate(_bob);

        (, , , , uint256 proposalId2_) = _createEmergencySetKeyProposal("key1", "value1", _alice);

        vm.prank(_bob);
        uint256 bobWeight_ = _emergencyGovernor.castVote(proposalId2_, yesSupport_);

        assertEq(bobWeight_, newPowerToken_.balanceOf(_bob));

        vm.prank(_alice);
        uint256 aliceWeight_ = _emergencyGovernor.castVote(proposalId2_, yesSupport_);

        assertEq(aliceWeight_, 0);

        vm.prank(_frank);
        uint256 frankWeight_ = _emergencyGovernor.castVote(proposalId2_, yesSupport_);

        assertEq(frankWeight_, newPowerToken_.balanceOf(_frank));

        vm.prank(_dave);
        uint256 daveWeight_ = _emergencyGovernor.castVote(proposalId2_, yesSupport_);

        assertEq(daveWeight_, newPowerToken_.balanceOf(_dave));
    }

    function test_resetToPower_variousBalances() external {
        _warpToNextTransferEpoch();

        // inflation producing proposal
        (, , , , uint256 proposalId1_) = _createSetKeyProposal("key1", "value1", _dave);

        _warpToNextVoteEpoch();

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 bobPowerBalance_ = _powerToken.getVotes(_bob);

        vm.prank(_bob);
        _standardGovernor.castVote(proposalId1_, yesSupport_); // inflation received by bob

        _warpToNextTransferEpoch();

        assertEq(_powerToken.getVotes(_bob), (bobPowerBalance_ * 11) / 10);

        _resetToPowerHolders();

        IPowerToken newPowerToken_ = IPowerToken(_registrar.powerToken());

        assertEq(newPowerToken_.totalSupply(), _powerToken.INITIAL_SUPPLY());

        uint256 resetSnapshotEpoch_ = _currentEpoch() - 1;

        assertEq(
            newPowerToken_.getVotes(_alice) + newPowerToken_.getVotes(_bob) + newPowerToken_.getVotes(_carol),
            newPowerToken_.totalSupply()
        );

        // assertEq(
        //     newPowerToken_.getVotes(_alice),
        //     (_powerToken.INITIAL_SUPPLY() * _powerToken.getPastVotes(_alice, resetSnapshotEpoch_)) /
        //         _powerToken.pastTotalSupply(resetSnapshotEpoch_)
        // );
        // assertEq(
        //     newPowerToken_.getVotes(_bob),
        //     (_powerToken.INITIAL_SUPPLY() * _powerToken.getPastVotes(_bob, resetSnapshotEpoch_)) /
        //         _powerToken.pastTotalSupply(resetSnapshotEpoch_)
        // );

        // assertEq(
        //     newPowerToken_.getVotes(_carol),
        //     (_powerToken.INITIAL_SUPPLY() * _powerToken.getPastVotes(_carol, resetSnapshotEpoch_)) /
        //         _powerToken.pastTotalSupply(resetSnapshotEpoch_)
        // );
    }

    function _changeCashToken(address cashToken_, uint256 proposalFee_) internal {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.setCashToken.selector, cashToken_, proposalFee_);

        string memory description_ = "Update cash token";

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // Active

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        vm.prank(_dave);
        _zeroGovernor.castVote(proposalId_, yesSupport_);

        // depends on total supply, can require _dave + _eve or just _dave to vote
        if (uint256(_zeroGovernor.state(proposalId_)) == 1) {
            vm.prank(_eve);
            _zeroGovernor.castVote(proposalId_, yesSupport_);
        }

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // Succeeded

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 7); // Executed
    }

    function _createSetKeyProposal(
        bytes32 key_,
        bytes32 value_,
        address proposer_
    )
        internal
        returns (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_,
            uint256 proposalId_
        )
    {
        targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setKey.selector, bytes32(key_), bytes32(value_));

        description_ = "Set TEST_KEY to TEST_VALUE";

        vm.prank(proposer_);
        proposalId_ = _standardGovernor.propose(targets_, values_, callDatas_, description_);
    }

    function _createEmergencySetKeyProposal(
        bytes32 key_,
        bytes32 value_,
        address proposer_
    )
        internal
        returns (
            address[] memory targets_,
            uint256[] memory values_,
            bytes[] memory callDatas_,
            string memory description_,
            uint256 proposalId_
        )
    {
        targets_ = new address[](1);
        targets_[0] = address(_emergencyGovernor);

        values_ = new uint256[](1);

        callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_emergencyGovernor.setKey.selector, bytes32(key_), bytes32(value_));

        description_ = "Set TEST_KEY to TEST_VALUE";

        vm.prank(proposer_);
        proposalId_ = _emergencyGovernor.propose(targets_, values_, callDatas_, description_);
    }

    function _resetToZeroHolders() internal {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.resetToZeroHolders.selector);

        string memory description_ = "Reset to Zero holders";

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        vm.prank(_dave);
        _zeroGovernor.castVote(proposalId_, yesSupport_);

        // depends on total supply, can require _dave + _frank or just _dave to vote
        if (uint256(_zeroGovernor.state(proposalId_)) == 1) {
            vm.prank(_frank);
            _zeroGovernor.castVote(proposalId_, yesSupport_);
        }

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // Succeeded

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 7); // Executed
    }

    function _resetToPowerHolders() internal {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_zeroGovernor.resetToPowerHolders.selector);

        string memory description_ = "Reset to Power holders";

        vm.prank(_dave);
        uint256 proposalId_ = _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        vm.prank(_dave);
        _zeroGovernor.castVote(proposalId_, yesSupport_);

        // depends on total supply, can require _dave + _frank or just _dave to vote
        if (uint256(_zeroGovernor.state(proposalId_)) == 1) {
            vm.prank(_frank);
            _zeroGovernor.castVote(proposalId_, yesSupport_);
        }

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // Succeeded

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 7); // Executed
    }
}
