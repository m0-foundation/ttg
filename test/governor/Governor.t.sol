// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import "forge-std/console.sol";

contract VoteSPOGGovernorTest is SPOG_Base {
    address alice = createUser("alice");
    uint256 signerPrivateKey = 0xA11CE;
    address signer = vm.addr(signerPrivateKey);

    uint8 noVote = 0;
    uint8 yesVote = 1;

    event NewVoteQuorumProposal(uint256 indexed proposalId);

    // Setup function, add test-specific initializations here
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function proposeAddingNewListToSpog(string memory proposalDescription)
        private
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addNewList(address)", list);
        string memory description = proposalDescription;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create new proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        expectEmit();
        emit NewVoteQuorumProposal(proposalId);
        governor.propose(targets, values, calldatas, description);

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    // calculate vote token inflation rewards for voter
    function calculateVoteTokenInflationRewardsForVoter(
        address voter,
        uint256 proposalId,
        uint256 amountToBeSharedOnProRataBasis
    ) private view returns (uint256) {
        uint256 accountVotingTokenBalance = governor.getVotes(voter, governor.proposalSnapshot(proposalId));

        uint256 totalVotingTokenSupplyApplicable = spogVote.totalSupply() - amountToBeSharedOnProRataBasis;

        uint256 percentageOfTotalSupply = accountVotingTokenBalance * 100 / totalVotingTokenSupplyApplicable;

        uint256 inflationRewards = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        return inflationRewards;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_Propose_WhenCalledNotBySPOG() public {
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("append(address,address)", users.alice, list);
        string memory description = "add merchant to spog";

        // approve cash spend for proposal
        deployScript.cash().approve(address(spog), deployScript.tax());

        // revert when called not by SPOG, execute methods are closed to the public
        vm.expectRevert(abi.encodeWithSelector(ISPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        governor.propose(targets, values, calldatas, description);
    }

    function test_Revert_Execute_WhenCalledNotBySPOG() public {
        // propose adding a new list to spog
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("Add new list to spog");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        // revert when called not by SPOG, execute methods are closed to the public
        vm.expectRevert(abi.encodeWithSelector(ISPOGGovernor.CallerIsNotSPOG.selector, address(this)));
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_StartOfNextVotingPeriod() public {
        uint256 votingPeriod = governor.votingPeriod();
        uint256 startOfNextEpoch = governor.startOfNextEpoch();

        assertTrue(startOfNextEpoch > block.number);
        assertEq(startOfNextEpoch, block.number + votingPeriod);
    }

    function test_AccurateIncrementOfCurrentVotingPeriodEpoch() public {
        uint256 currentEpoch = governor.currentEpoch();

        assertEq(currentEpoch, 0); // initial value

        for (uint256 i = 0; i < 6; i++) {
            vm.roll(block.number + governor.votingDelay() + 1);

            currentEpoch = governor.currentEpoch();

            assertEq(currentEpoch, i + 1);
        }
    }

    function test_CanOnlyVoteOnAProposalAfterItsVotingDelay() public {
        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");

        // spogVote balance of voter valid for voting
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);

        // check that proposal has 1 vote
        (uint256 proposalNoVotes, uint256 proposalYesVotes) = governor.proposalVoteVotes(proposalId);

        console.log("proposalNoVotes: ", proposalNoVotes);
        console.log("proposalYesVotes: ", proposalYesVotes);

        assertEq(proposalYesVotes, spogVoteBalance, "Proposal does not have expected yes vote");
        assertEq(proposalNoVotes, 0, "Proposal does not have 0 no vote");
    }

    function test_CanVoteOnMultipleProposalsAfterItsVotingDelay() public {
        // Proposal 1 and 2

        // propose adding a new list to spog
        (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
        (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

        // spogVote balance of voter
        uint256 spogVoteBalance = spogVote.balanceOf(address(this));

        // revert happens when voting on proposal before voting period has started
        vm.expectRevert("Governor: vote not currently active");
        governor.castVote(proposalId, yesVote);

        vm.expectRevert("Governor: vote not currently active");
        governor.castVote(proposalId2, noVote);

        // check proposal is pending. Note voting is not active until voteDelay is reached
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

        assertTrue(
            governor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        governor.castVote(proposalId2, noVote);

        // check that proposal has 1 vote
        (uint256 noVotes, uint256 yesVotes) = governor.proposalVoteVotes(proposalId);
        (uint256 noVotes2, uint256 yesVotes2) = governor.proposalVoteVotes(proposalId2);

        assertEq(yesVotes, spogVoteBalance, "Proposal does not have expected yes vote");
        assertEq(noVotes, 0, "Proposal does not have 0 no vote");

        assertEq(noVotes2, spogVoteBalance, "Proposal2 does not have expected no vote");
        assertEq(yesVotes2, 0, "Proposal2 does not have 0 yes vote");

        // Proposal 3

        // Add another proposal and voting can only happen after vote delay
        (uint256 proposalId3,,,,) = proposeAddingNewListToSpog("Proposal3 for new list to spog");

        // spogVote balance of voter before casting vote on proposal 3
        uint256 spogVoteBalanceForProposal3 = spogVote.balanceOf(address(this));

        // vm.expectRevert("Governor: vote not currently active");
        // governor.castVote(proposalId3, noVote);

        assertTrue(
            governor.state(proposalId3) == IGovernor.ProposalState.Pending, "Proposal3 is not in an pending state"
        );

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId3, noVote);

        (uint256 noVotes3, uint256 yesVotes3) = governor.proposalVoteVotes(proposalId3);

        assertEq(noVotes3, spogVoteBalanceForProposal3, "Proposal3 does not have expected no vote");
        assertEq(yesVotes3, 0, "Proposal3 does not have 0 yes vote");
    }

    // function test_CanBatchVoteOnMultipleProposalsAfterItsVotingDelay() public {
    //     // propose adding a new list to spog
    //     (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
    //     (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

    //     uint256[] memory proposals = new uint256[](2);
    //     proposals[0] = proposalId;
    //     proposals[1] = proposalId2;

    //     uint8[] memory support = new uint8[](2);
    //     support[0] = yesVote;
    //     support[1] = noVote;

    //     // revert happens when voting on proposal before voting period has started
    //     vm.expectRevert("Governor: vote not currently active");
    //     governor.castVotes(proposals, support);

    //     // check proposal is pending. Note voting is not active until voteDelay is reached
    //     assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

    //     assertTrue(
    //         governor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
    //     );

    //     // fast forward to an active voting period
    //     vm.roll(block.number + governor.votingDelay() + 1);

    //     // cast vote on proposals
    //     governor.castVotes(proposals, support);

    //     // check that proposal has 1 vote
    //     (uint256 noVotes, uint256 yesVotes) = governor.proposalVoteVotes(proposalId);
    //     (uint256 noVotes2, uint256 yesVotes2) = governor.proposalVoteVotes(proposalId2);

    //     // spogVote balance of voter
    //     uint256 spogVoteBalance = spogVote.balanceOf(address(this));

    //     assertTrue(yesVotes == spogVoteBalance, "Proposal does not have expected yes vote");
    //     assertTrue(noVotes == 0, "Proposal does not have 0 no vote");

    //     assertTrue(noVotes2 == spogVoteBalance, "Proposal2 does not have expected no vote");
    //     assertTrue(yesVotes2 == 0, "Proposal2 does not have 0 yes vote");
    // }

    // function test_CanBatchVoteOnMultipleProposalsWithSignatureAfterItsVotingDelay() public {
    //     // mint spogVote to signer and self-delegate
    //     spogVote.mint(signer, 100e18);
    //     spogVote.delegate(signer);

    //     // propose adding a new list to spog
    //     (uint256 proposalId,,,,) = proposeAddingNewListToSpog("Add new list to spog");
    //     (uint256 proposalId2,,,,) = proposeAddingNewListToSpog("Another new list to spog");

    //     uint256[] memory proposals = new uint256[](2);
    //     proposals[0] = proposalId;
    //     proposals[1] = proposalId2;

    //     uint8[] memory support = new uint8[](2);
    //     support[0] = yesVote;
    //     support[1] = noVote;

    //     // bytes32 BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    //     uint8[] memory vs = new uint8[](proposals.length);
    //     bytes32[] memory rs = new bytes32[](proposals.length);
    //     bytes32[] memory ss = new bytes32[](proposals.length);

    //     for (uint256 i; i < proposals.length;) {
    //         bytes32 digest = governor.hashVote(proposals[i], support[i]);

    //         (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
    //         vs[i] = v;
    //         rs[i] = r;
    //         ss[i] = s;

    //         unchecked {
    //             ++i;
    //         }
    //     }

    //     // revert happens when voting on proposal before voting period has started
    //     vm.expectRevert("Governor: vote not currently active");
    //     governor.castVotesBySig(proposals, support, vs, rs, ss);

    //     // check proposal is pending. Note voting is not active until voteDelay is reached
    //     assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Proposal is not in an pending state");

    //     assertTrue(
    //         governor.state(proposalId2) == IGovernor.ProposalState.Pending, "Proposal2 is not in an pending state"
    //     );

    //     // fast forward to an active voting period
    //     vm.roll(block.number + governor.votingDelay() + 1);

    //     // cast vote on proposals
    //     governor.castVotesBySig(proposals, support, vs, rs, ss);

    //     // check that proposal has 1 vote
    //     (uint256 noVotes, uint256 yesVotes) = governor.proposalVoteVotes(proposalId);
    //     (uint256 noVotes2, uint256 yesVotes2) = governor.proposalVoteVotes(proposalId2);

    //     // spogVote balance of voter
    //     uint256 spogVoteBalance = spogVote.balanceOf(signer);

    //     assertTrue(yesVotes == spogVoteBalance, "Proposal does not have expected yes vote");
    //     assertTrue(noVotes == 0, "Proposal does not have 0 no vote");

    //     assertTrue(noVotes2 == spogVoteBalance, "Proposal2 does not have expected no vote");
    //     assertTrue(yesVotes2 == 0, "Proposal2 does not have 0 yes vote");
    // }

    function test_VoteTokenSupplyInflatesAtTheBeginningOfEachVotingPeriod() public {
        // epoch 0
        uint256 spogVoteSupplyBefore = spogVote.totalSupply();
        uint256 vaultVoteTokenBalanceBefore = spogVote.balanceOf(address(voteVault));
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        uint256 spogVoteSupplyAfterFirstInflation = spogVote.totalSupply();
        uint256 amountAddedByInflation = (spogVoteSupplyBefore * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterFirstInflation,
            spogVoteSupplyBefore + amountAddedByInflation,
            "Vote token supply didn't inflate correctly"
        );

        // check that vault has received the vote inflationary supply
        uint256 vaultVoteTokenBalanceAfterFirstInflation = spogVote.balanceOf(address(voteVault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstInflation,
            vaultVoteTokenBalanceBefore + amountAddedByInflation,
            "Vault did not receive the accurate vote inflationary supply"
        );

        // fast forward to an active voting period. epoch 1
        vm.roll(block.number + governor.votingDelay() + 1);
        governor.castVote(proposalId, yesVote);

        uint256 spogVoteSupplyAfterVoting = spogVote.totalSupply();

        assertEq(
            spogVoteSupplyAfterFirstInflation, spogVoteSupplyAfterVoting, "Vote token supply got inflated by voting"
        );

        // start of new epoch 2
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
        uint256 spogVoteSupplyAfterExecution = spogVote.totalSupply();

        assertEq(
            spogVoteSupplyAfterFirstInflation,
            spogVoteSupplyAfterExecution,
            "Vote token supply got inflated by execution"
        );

        // new proposal, inflate supply
        proposeAddingNewListToSpog("new list to spog, again");

        uint256 spogVoteSupplyAfterSecondInflation = spogVote.totalSupply();
        uint256 amountAddedBySecondInflation = (spogVoteSupplyAfterFirstInflation * deployScript.inflator()) / 100;

        assertEq(
            spogVoteSupplyAfterSecondInflation,
            spogVoteSupplyAfterFirstInflation + amountAddedBySecondInflation,
            "Vote token supply didn't inflate correctly during the second inflation"
        );
    }

    function test_ValueTokenSupplyDoesNotInflateAtTheBeginningOfEachVotingPeriodWithoutActivity() public {
        uint256 spogValueSupplyBefore = spogValue.totalSupply();

        uint256 vaultVoteTokenBalanceBefore = spogValue.balanceOf(address(voteVault));

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + governor.votingDelay() + 1);

        uint256 spogValueSupplyAfterFirstPeriod = spogValue.totalSupply();

        assertEq(spogValueSupplyAfterFirstPeriod, spogValueSupplyBefore, "Vote token supply inflated incorrectly");

        // check that vault has received the vote inflationary supply
        // TODO: clean up names here
        uint256 vaultVoteTokenBalanceAfterFirstPeriod = spogValue.balanceOf(address(voteVault));
        assertEq(
            vaultVoteTokenBalanceAfterFirstPeriod,
            vaultVoteTokenBalanceBefore,
            "Vault received an inaccurate vote inflationary supply"
        );

        // start of new epoch inflation is triggered
        vm.roll(block.number + deployScript.time() + 1);

        uint256 spogValueSupplyAfterSecondPeriod = spogValue.totalSupply();

        assertEq(
            spogValueSupplyAfterSecondPeriod,
            spogValueSupplyAfterFirstPeriod,
            "Vote token supply inflated incorrectly in the second period"
        );
    }

    function test_ProposalsShouldBeAllowedAfterInactiveEpoch() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeAddingNewListToSpog("new list to spog");

        // fast forward to an active voting period. Inflate vote token supply
        vm.roll(block.number + governor.votingDelay() + 1);

        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + deployScript.time() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);

        // fast forward 5 epochs
        vm.roll(block.number + 5 * governor.votingDelay() + 1);

        // should not revert
        proposeAddingNewListToSpog("new list to spog 2");
    }
}
