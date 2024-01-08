// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../../lib/forge-std/src/Test.sol";

import { IntegrationBaseSetup, IBatchGovernor, IGovernor } from "../IntegrationBaseSetup.t.sol";

contract PowerInflationZeroRewards_IntegrationTest is IntegrationBaseSetup {
    // _alice = 55;
    // _bob  = 25;
    // _carol = 20;
    function test_powerInflation_selfDelegationOnlyNoTransfersOrRedelegations() external {
        uint256 aliceBalance_ = _powerToken.balanceOf(_alice);
        uint256 bobBalance_ = _powerToken.balanceOf(_bob);
        uint256 carolBalance_ = _powerToken.balanceOf(_carol);

        _warpToNextTransferEpoch();

        uint256 proposalId1_ = _createStandardProposal("key1", "value1");
        uint256 proposalId2_ = _createStandardProposal("key2", "value2");

        _warpToNextVoteEpoch();

        assertEq(_powerToken.targetSupply(), _getInflatedAmount(_powerToken.totalSupply()));

        uint256 proposalId3_ = _createStandardProposal("key3", "value3");

        // Target supply stays the same
        assertEq(_powerToken.targetSupply(), _getInflatedAmount(_powerToken.totalSupply()));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.No));

        assertEq(_powerToken.getVotes(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);

        vm.prank(_bob);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        vm.prank(_bob);
        _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.No));

        assertEq(_powerToken.getVotes(_bob), _getInflatedAmount(bobBalance_));
        assertEq(_powerToken.balanceOf(_bob), bobBalance_);

        vm.prank(_carol);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        vm.prank(_carol);
        _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.No));

        assertEq(_powerToken.getVotes(_carol), _getInflatedAmount(carolBalance_));
        assertEq(_powerToken.balanceOf(_carol), carolBalance_);

        _warpToNextTransferEpoch();

        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_bob), _getInflatedAmount(bobBalance_));
        assertEq(_powerToken.balanceOf(_carol), _getInflatedAmount(carolBalance_));

        _warpToNextVoteEpoch();

        assertEq(_powerToken.targetSupply(), _getInflatedAmount(_powerToken.totalSupply()));

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId3_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_powerToken.getVotes(_alice), _getInflatedAmount(_getInflatedAmount(aliceBalance_)));
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_));

        vm.prank(_carol);
        _standardGovernor.castVote(proposalId3_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_powerToken.getVotes(_carol), _getInflatedAmount(_getInflatedAmount(carolBalance_)));
        assertEq(_powerToken.balanceOf(_carol), _getInflatedAmount(carolBalance_));

        _warpToNextEpoch();

        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(_getInflatedAmount(aliceBalance_)));
        assertEq(_powerToken.balanceOf(_carol), _getInflatedAmount(_getInflatedAmount(carolBalance_)));

        // Bobs inflation is up for auction
        assertEq(
            _powerToken.amountToAuction(),
            _getInflatedAmount(_getInflatedAmount(bobBalance_)) - _getInflatedAmount(bobBalance_)
        );

        _warpToNextEpoch(); // voting epoch

        assertEq(_powerToken.amountToAuction(), 0);

        _warpToNextEpoch(); // transfer epoch

        assertEq(
            _powerToken.amountToAuction(),
            _getInflatedAmount(_getInflatedAmount(bobBalance_)) - _getInflatedAmount(bobBalance_)
        );
    }

    function test_powerInflation_selfDelegationOnlyTransfersAndRedelegations() external {
        uint256 aliceBalance_ = _powerToken.balanceOf(_alice);
        uint256 bobBalance_ = _powerToken.balanceOf(_bob);

        _warpToNextTransferEpoch();

        uint256 proposalId1_ = _createStandardProposal("key1", "value1");
        uint256 proposalId2_ = _createStandardProposal("key2", "value2");

        _warpToNextVoteEpoch();

        // Alice votes on all proposals
        vm.prank(_alice);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_powerToken.getVotes(_alice), aliceBalance_);
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);

        vm.prank(_alice);
        _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.No));

        // Alice's voting power inflation is rewarded immediately
        assertEq(_powerToken.getVotes(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_alice), aliceBalance_);

        // Bob votes on just one proposal
        vm.prank(_bob);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        assertEq(_powerToken.getVotes(_bob), bobBalance_);
        assertEq(_powerToken.balanceOf(_bob), bobBalance_);

        _warpToNextTransferEpoch();

        // Alice's balance inflation is rewarded once the epoch is over
        assertEq(_powerToken.getVotes(_alice), _getInflatedAmount(aliceBalance_));
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_));

        // Bob's inflation is not rewarded once the epoch is over, since he only voted on 1 of 2 proposals
        assertEq(_powerToken.getVotes(_bob), bobBalance_);
        assertEq(_powerToken.balanceOf(_bob), bobBalance_);

        // New proposal
        uint256 proposalId3_ = _createStandardProposal("key3", "value3");
        uint256 transferAmountToDave_ = 1_050;

        vm.prank(_alice);
        _powerToken.transfer(_dave, 1_050);

        assertEq(_powerToken.getVotes(_alice), _getInflatedAmount(aliceBalance_) - transferAmountToDave_);
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_) - transferAmountToDave_);

        assertEq(_powerToken.getVotes(_dave), transferAmountToDave_);
        assertEq(_powerToken.balanceOf(_dave), transferAmountToDave_);

        vm.prank(_alice);
        _powerToken.delegate(_eve);

        assertEq(_powerToken.getVotes(_alice), 0);
        assertEq(_powerToken.balanceOf(_alice), _getInflatedAmount(aliceBalance_) - transferAmountToDave_);

        assertEq(_powerToken.getVotes(_eve), _getInflatedAmount(aliceBalance_) - transferAmountToDave_);
        assertEq(_powerToken.balanceOf(_eve), 0);

        uint256 transferAmountToEve_ = 250;

        vm.prank(_bob);
        _powerToken.transfer(_eve, transferAmountToEve_);

        assertEq(_powerToken.getVotes(_bob), bobBalance_ - transferAmountToEve_);
        assertEq(_powerToken.balanceOf(_bob), bobBalance_ - transferAmountToEve_);

        assertEq(
            _powerToken.getVotes(_eve),
            _getInflatedAmount(aliceBalance_) - transferAmountToDave_ + transferAmountToEve_
        );
        assertEq(_powerToken.balanceOf(_eve), transferAmountToEve_);

        _warpToNextVoteEpoch();

        vm.prank(_eve);
        uint256 eveWeight_ = _standardGovernor.castVote(proposalId3_, uint8(IBatchGovernor.VoteType.Yes));
        assertEq(eveWeight_, _getInflatedAmount(aliceBalance_) - transferAmountToDave_ + transferAmountToEve_);

        vm.prank(_dave);
        uint256 daveWeight_ = _standardGovernor.castVote(proposalId3_, uint8(IBatchGovernor.VoteType.Yes));
        assertEq(daveWeight_, transferAmountToDave_);
    }

    function test_powerInflation_multiplDelegatesTransfersAndRedelegations() external {
        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _powerToken.delegate(_eve);

        vm.prank(_bob);
        _powerToken.delegate(_eve);

        vm.prank(_carol);
        _powerToken.delegate(_eve);

        uint256 proposalId1_ = _createStandardProposal("key1", "value1");

        _warpToNextVoteEpoch();

        vm.prank(_eve);
        _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));

        // Voting power of Eve is inflated
        assertEq(_powerToken.getVotes(_eve), 11_000);

        // Alice, Bob and Carol do not yet have balances inflation
        assertEq(_powerToken.balanceOf(_alice), 5_500);
        assertEq(_powerToken.balanceOf(_bob), 2_500);
        assertEq(_powerToken.balanceOf(_carol), 2_000);

        _warpToNextTransferEpoch();

        // Alice, Bob and Carol have balances inflation
        assertEq(_powerToken.balanceOf(_alice), 6_050);
        assertEq(_powerToken.balanceOf(_bob), 2_750);
        assertEq(_powerToken.balanceOf(_carol), 2_200);

        vm.prank(_alice);
        _powerToken.transfer(_dave, 1_050);

        assertEq(_powerToken.getVotes(_eve), 9_950);
        assertEq(_powerToken.getVotes(_dave), 1_050);

        uint256 proposalId2_ = _createStandardProposal("key2", "value2");

        _warpToNextVoteEpoch();

        // Eve votes on proposal 2
        vm.prank(_eve);
        _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.Yes));

        // Voting power of Eve is inflated
        assertEq(_powerToken.getVotes(_eve), 10_945);

        // Alice, Bob and Carol do not yet have balances inflation
        assertEq(_powerToken.balanceOf(_alice), 5_000);
        assertEq(_powerToken.balanceOf(_bob), 2_750);
        assertEq(_powerToken.balanceOf(_carol), 2_200);

        _warpToNextVoteEpoch();

        // Alice, Bob and Carol have balances inflation
        assertEq(_powerToken.balanceOf(_alice), 5_500);
        assertEq(_powerToken.balanceOf(_bob), 3_025);
        assertEq(_powerToken.balanceOf(_carol), 2_420);

        assertEq(_powerToken.getVotes(_dave), 1_050);
        assertEq(_powerToken.balanceOf(_dave), 1_050);
    }

    function test_zeroRewards_multiplDelegatesTransfersAndRedelegations() external {
        _warpToNextTransferEpoch();

        vm.prank(_alice);
        _powerToken.delegate(_eve);

        vm.prank(_bob);
        _powerToken.delegate(_eve);

        uint256 eveZeroBalance_ = _zeroToken.balanceOf(_eve);

        uint256 proposalId1_ = _createStandardProposal("key1", "value1");

        _warpToNextVoteEpoch();

        vm.prank(_eve);
        uint256 eveWeight_ = _standardGovernor.castVote(proposalId1_, uint8(IBatchGovernor.VoteType.Yes));
        assertEq(eveWeight_, 8_000);

        // Voting power of Eve is inflated
        assertEq(_powerToken.getVotes(_eve), 8_800);
        assertEq(_zeroToken.balanceOf(_eve) - eveZeroBalance_, (5_000_000e6 * 800) / 1000);

        eveZeroBalance_ = _zeroToken.balanceOf(_eve);

        // Carol doesn't vote

        _warpToNextTransferEpoch();

        uint256 proposalId2_ = _createStandardProposal("key1", "value1");

        _warpToNextVoteEpoch();

        vm.prank(_eve);
        eveWeight_ = _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.Yes));
        assertEq(eveWeight_, 8_800);

        assertEq(_powerToken.getVotes(_eve), 9_680);
        assertEq(_zeroToken.balanceOf(_eve) - eveZeroBalance_, 4074074074074); // (5_000_000e6 * 880) / 1080

        vm.prank(_carol);
        uint256 carolWeight_ = _standardGovernor.castVote(proposalId2_, uint8(IBatchGovernor.VoteType.Yes));
        assertEq(carolWeight_, 2_000);

        assertEq(_powerToken.getVotes(_carol), 2_200);
        assertEq(_zeroToken.balanceOf(_carol), 925925925925); // (5_000_000e6 * 200) / 1080
    }

    function _createStandardProposal(bytes32 key_, bytes32 value_) internal returns (uint256 proposalId_) {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_standardGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(_standardGovernor.setKey.selector, key_, value_);

        string memory description_ = "Set key in Registrar";

        vm.prank(_dave);
        return _standardGovernor.propose(targets_, values_, callDatas_, description_);
    }

    function _getInflatedAmount(uint256 amount_) internal view returns (uint256 inflatedAmount_) {
        uint256 inflation_ = _powerToken.participationInflation(); // 10%
        return amount_ + (amount_ * inflation_) / 10_000;
    }
}
