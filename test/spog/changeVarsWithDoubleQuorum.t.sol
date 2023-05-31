// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_change is SPOG_Base {
    uint8 internal yesVote;
    uint8 internal noVote;
    address internal alice;

    event Proposal(uint256 indexed epoch, uint256 indexed proposalId, ISPOGGovernor.ProposalType indexed proposalType);
    event TaxRangeChanged(uint256 oldLowerRange, uint256 newLowerRange, uint256 oldUpperRange, uint256 newUpperRange);
    event ValueQuorumNumeratorUpdated(uint256 oldValueQuorumNumerator, uint256 newValueQuorumNumerator);
    event VoteQuorumNumeratorUpdated(uint256 oldVoteQuorumNumerator, uint256 newVoteQuorumNumerator);

    function setUp() public override {
        super.setUp();

        yesVote = 1;
        noVote = 0;

        alice = payable(makeAddr("alice"));
    }

    function proposeTaxRangeChange(string memory proposalDescription)
        private
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("changeTaxRange(uint256,uint256)", 10e18, 12e18);
        string memory description = proposalDescription;
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // uint256 epoch = governor.currentEpoch();

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function test_Revert_ChangeTaxRange_WhenNotCalledByGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.changeTaxRange(10e18, 12e18);
    }

    function test_Revert_Change_WhenValueHoldersDoNotVote() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 taxLowerBound = spog.taxLowerBound();
        uint256 taxUpperBound = spog.taxUpperBound();

        // give alice vote power
        ISPOGVotes(vote).mint(alice, 95e18);
        vm.startPrank(alice);
        ISPOGVotes(vote).delegate(alice);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 noVoteVotes, uint256 yesVoteVotes) = governor.proposalVotes(proposalId);
        (uint256 noValueVotes, uint256 yesValueVotes) = governor.proposalValueVotes(proposalId);

        assertTrue(yesVoteVotes == 95e18, "Yes vote votes should be 95");
        assertTrue(noVoteVotes == 0, "No vote votes should be 0");
        assertTrue(yesValueVotes == 0, "Yes value votes should be 0");
        assertTrue(noValueVotes == 0, "No value votes should be 0");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check that execute function is reverted if value quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that tax range has not been changed
        assertTrue(
            spog.taxLowerBound() == taxLowerBound && spog.taxUpperBound() == taxUpperBound,
            "Tax range should not have been changed"
        );
    }

    function test_Revert_Change_WhenVoteHoldersDoNotVote() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 taxLowerBound = spog.taxLowerBound();
        uint256 taxUpperBound = spog.taxUpperBound();

        // give alice vote power
        ISPOGVotes(value).mint(alice, 95e18);
        vm.startPrank(alice);
        ISPOGVotes(value).delegate(alice);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);
        vm.stopPrank();

        (uint256 noVoteVotes, uint256 yesVoteVotes) = governor.proposalVotes(proposalId);
        (uint256 noValueVotes, uint256 yesValueVotes) = governor.proposalValueVotes(proposalId);

        assertTrue(yesVoteVotes == 0, "Yes vote votes should be 0");
        assertTrue(noVoteVotes == 0, "No vote votes should be 0");
        assertTrue(yesValueVotes == 95e18, "Yes value votes should be 95e18");
        assertTrue(noValueVotes == 0, "No value votes should be 0");

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // Check that execute function is reverted if value quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);

        // assert that tax range has not been changed
        assertTrue(
            spog.taxLowerBound() == taxLowerBound && spog.taxUpperBound() == taxUpperBound,
            "Tax range should not have been changed"
        );
    }

    function test_Revert_ChangeTaxRange_WhenVoteValueHoldersDoNotAgree() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, noVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        assertFalse(governor.state(proposalId) == IGovernor.ProposalState.Succeeded);

        // Check that execute function is reverted if vote quorum is not reached
        vm.expectRevert("Governor: proposal not successful");
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_ChangeTaxRange_Success() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeTaxRangeChange("Change tax range in spog");

        uint256 oldTaxLowerBound = spog.taxLowerBound();
        uint256 oldTaxUpperBound = spog.taxUpperBound();

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that TaxRangeChanged event was emitted
        expectEmit();
        emit TaxRangeChanged(oldTaxLowerBound, 10e18, oldTaxUpperBound, 12e18);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 newTaxLowerBound = spog.taxLowerBound();
        uint256 newTaxUpperBound = spog.taxUpperBound();

        // assert that tax hange has been changed
        assertTrue(newTaxLowerBound == 10e18, "Tax range lower bound has not changed");
        assertTrue(newTaxUpperBound == 12e18, "Tax range upper bound has not changed");
    }

    function test_UpdateVoteQuorum_Success() public {
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("updateVoteQuorumNumerator(uint256)", 15);
        string memory description = "Change vote quorum numerator";
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // uint256 epoch = governor.currentEpoch();

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that VoteQuorumNumeratorUpdated event was emitted
        expectEmit();
        emit VoteQuorumNumeratorUpdated(4, 15);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 newVoteQuorumNumerator = governor.voteQuorumNumerator();
        assertTrue(newVoteQuorumNumerator == 15, "Vote quorum numerator has not changed");
    }

    function test_UpdateValueQuorum_Success() public {
        address[] memory targets = new address[](1);
        targets[0] = address(governor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        bytes memory callData = abi.encodeWithSignature("updateValueQuorumNumerator(uint256)", 16);
        string memory description = "Change value quorum numerator";
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // uint256 epoch = governor.currentEpoch();

        // create proposal
        cash.approve(address(spog), tax);

        // TODO: add checks for 2 emitted events
        // expectEmit();
        // emit ProposalCreated();
        // expectEmit();
        // emit Proposal(epoch, proposalId, ISPOGGovernor.ProposalType.Double);
        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);
        assertTrue(spogProposalId == proposalId, "spog proposal ids don't match");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // vote and value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // check that ValueQuorumNumeratorUpdated event was emitted
        expectEmit();
        emit ValueQuorumNumeratorUpdated(4, 16);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 newValueQuorumNumerator = governor.valueQuorumNumerator();
        assertTrue(newValueQuorumNumerator == 16, "Value quorum numerator has not changed");
    }
}
