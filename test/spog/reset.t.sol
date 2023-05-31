// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_reset is SPOG_Base {
    uint8 internal yesVote;

    event ResetExecuted(address indexed newVoteToken, address indexed newVoteGovernor, uint256 indexed snapshotId);

    function setUp() public override {
        super.setUp();

        yesVote = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function createNewGovernor(address valueToken) private returns (address) {
        // deploy vote governor from factory
        VoteToken newVoteToken = new VoteToken("new SPOGVote", "vote", valueToken);
        // grant minter role to new voteToken deployer
        IAccessControl(address(newVoteToken)).grantRole(newVoteToken.MINTER_ROLE(), address(this));

        // mint new vote tokens to address(this) and self-delegate
        newVoteToken.mint(address(this), 100e18);
        newVoteToken.delegate(address(this));

        uint256 time = 15; // in blocks
        uint256 voteQuorum = 5;
        uint256 valueQuorum = 5;
        DualGovernor newGovernor =
            new DualGovernor("new SPOGGovernor", address(newVoteToken), valueToken, voteQuorum, valueQuorum, time);

        return address(newGovernor);
    }

    function proposeGovernanceReset(string memory proposalDescription, address valueToken)
        private
        returns (uint256, address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        vm.roll(deployScript.time() * 2);

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        address newGovernor = createNewGovernor(valueToken);
        bytes memory callData = abi.encodeWithSignature("reset(address,address)", newGovernor, address(voteVault));
        string memory description = proposalDescription;
        calldatas[0] = callData;

        bytes32 hashedDescription = keccak256(abi.encodePacked(description));
        uint256 proposalId = governor.hashProposal(targets, values, calldatas, hashedDescription);

        // create proposal
        cash.approve(address(spog), 12 * deployScript.tax());

        // Check the event is emitted
        // TODO: check proposal
        // expectEmit();
        // emit NewValueQuorumProposal(proposalId);

        uint256 spogProposalId = governor.propose(targets, values, calldatas, description);

        // Make sure the proposal is immediately (+1 block) votable
        assertEq(governor.proposalSnapshot(proposalId), block.number + 1);

        assertTrue(spogProposalId == proposalId, "spog proposal id does not match value governor proposal id");

        return (proposalId, targets, values, calldatas, hashedDescription);
    }

    function executeValidProposal() private {
        DualGovernor governor = DualGovernor(payable(address(spog.governor())));
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("addList(address)", list);
        string memory description = "Add new list";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(targets, values, calldatas, description);

        // vote on proposal
        cash.approve(address(spog), deployScript.tax());
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        // execute proposal
        governor.execute(targets, values, calldatas, hashedDescription);
    }

    function test_Revert_Reset_WhenNotCalledByGovernance() public {
        vm.expectRevert(ISPOG.OnlyGovernor.selector);
        spog.reset(payable(address(governor)), address(voteVault));
    }

    function test_Reset_Success() public {
        (
            uint256 proposalId,
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 hashedDescription
        ) = proposeGovernanceReset("Propose reset of vote governance", address(value));

        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Not in pending state");

        // fast forward to an active voting period
        vm.roll(block.number + 2);
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Active, "Not in active state");

        // value holders vote on proposal
        governor.castVote(proposalId, yesVote);

        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        address governorBeforeFork = address(spog.governor());

        vm.expectEmit(false, false, false, false);
        address anyAddress = address(0);
        emit ResetExecuted(anyAddress, anyAddress, 0);
        governor.execute(targets, values, calldatas, hashedDescription);

        assertFalse(address(spog.governor()) == governorBeforeFork, "Governor was not reset");
        // TODO: fix interfaces
        assertEq(
            DualGovernor(payable(address(spog.governor()))).voteQuorumNumerator(),
            5,
            "Governor quorum was not set correctly"
        );
        assertEq(
            DualGovernor(payable(address(spog.governor()))).votingPeriod(),
            15,
            "Governor voting delay was not set correctly"
        );

        // Make sure governance is functional
        executeValidProposal();
    }

    function test_Reset_VoteAndValueTokensAreNotInflated() public {
        uint256 voteTokenInitialBalanceForVault = vote.balanceOf(address(voteVault));
        uint256 valueTokenInitialBalanceForVault = value.balanceOf(address(voteVault));
        uint256 voteTotalBalance = vote.totalSupply();
        uint256 valueTotalBalance = value.totalSupply();

        proposeGovernanceReset("Propose reset of vote governance", address(value));

        uint256 voteTokenBalanceAfterProposal = vote.balanceOf(address(voteVault));
        uint256 valueTokenBalanceAfterProposal = value.balanceOf(address(voteVault));
        uint256 voteTotalBalanceAfterProposal = vote.totalSupply();
        uint256 valueTotalBalanceAfterProposal = value.totalSupply();
        assertEq(
            voteTokenInitialBalanceForVault,
            voteTokenBalanceAfterProposal,
            "vault should have the same balance of vote tokens after reset proposal"
        );
        assertEq(
            valueTokenInitialBalanceForVault,
            valueTokenBalanceAfterProposal,
            "vault should have the same balance of value tokens after reset proposal"
        );
        assertEq(
            voteTotalBalance,
            voteTotalBalanceAfterProposal,
            "total supply of vote tokens should not change after reset proposal"
        );
        assertEq(
            valueTotalBalance,
            valueTotalBalanceAfterProposal,
            "total supply of value tokens should not change after reset proposal"
        );
    }
}
