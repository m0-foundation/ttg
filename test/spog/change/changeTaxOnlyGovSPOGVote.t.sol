// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/shared/SPOG_Base.t.sol";

contract SPOG_changeTax is SPOG_Base {
    uint256 internal newTaxValue;
    uint8 internal yesVote;

    event TaxChanged(uint256 indexed tax);

    function setUp() public override {
        super.setUp();
        newTaxValue = deployScript.taxRange(1);
        yesVote = 1;
    }

    function test_Revert_ChangeTaxWhenNotCalledFromGovernance() public {
        vm.expectRevert("SPOG: Only GovSPOGVote");
        spog.changeTax(newTaxValue);
    }

    function test_Revert_ChangeTaxMustBeProposedByVoteHoldersOnly() public {
        // value holders vote on proposal
        address[] memory targetsForValueHolders = new address[](1);
        targetsForValueHolders[0] = address(spog);
        uint256[] memory valuesForValueHolders = new uint256[](1);
        valuesForValueHolders[0] = 0;
        bytes[] memory calldatasForValueHolders = new bytes[](1);

        calldatasForValueHolders[0] = abi.encodeWithSignature("changeTax(uint256)", newTaxValue);
        string memory descriptionForValueHolders = "GovSPOGValue change tax variable in spog";

        (bytes32 hashedDescriptionForValueHolders, uint256 proposalIdForValueHolders) =
        getProposalIdAndHashedDescription(
            govSPOGValue,
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            descriptionForValueHolders
        );

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(
            IGovSPOG(address(govSPOGValue)),
            targetsForValueHolders,
            valuesForValueHolders,
            calldatasForValueHolders,
            descriptionForValueHolders
        );

        vm.roll(block.number + govSPOGValue.votingDelay() + 1);

        govSPOGValue.castVote(proposalIdForValueHolders, yesVote);
        // fast forward to end of govSPOGValue voting period
        vm.roll(block.number + deployScript.forkTime() + 1);

        vm.expectRevert("SPOG: Only GovSPOGVote");
        govSPOGValue.execute(
            targetsForValueHolders, valuesForValueHolders, calldatasForValueHolders, hashedDescriptionForValueHolders
        );

        (uint256 taxValueCheck,,,,,) = spog.spogData();
        // assert that tax was not modified
        assertTrue(taxValueCheck == deployScript.tax(), "Tax must not have changed");
    }

    function test_Revert_WhenTaxValueIsOutOfTaxRangeBounds() public {
        uint256 outOfBoundsTaxValue = deployScript.taxRange(1) + 1;

        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("changeTax(uint256)", outOfBoundsTaxValue);
        string memory description = "Change tax variable in spog";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(govSPOGVote, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(IGovSPOG(address(govSPOGVote)), targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        vm.expectRevert("SPOG: Tax out of range");
        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        (uint256 taxFirstCheck,,,,,) = spog.spogData();

        // assert that tax has not been modified
        assertFalse(taxFirstCheck == outOfBoundsTaxValue, "Tax should not have been changed");
    }

    function test_ChangeTaxViaProposalByGovSPOGVote() public {
        // create proposal to change variable in spog
        address[] memory targets = new address[](1);
        targets[0] = address(spog);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("changeTax(uint256)", newTaxValue);
        string memory description = "Change tax variable in spog";

        (bytes32 hashedDescription, uint256 proposalId) =
            getProposalIdAndHashedDescription(govSPOGVote, targets, values, calldatas, description);

        // vote on proposal
        deployScript.cash().approve(address(spog), deployScript.tax());
        spog.propose(IGovSPOG(address(govSPOGVote)), targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + govSPOGVote.votingDelay() + 1);

        // cast vote on proposal
        govSPOGVote.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + deployScript.voteTime() + 1);

        govSPOGVote.execute(targets, values, calldatas, hashedDescription);

        (uint256 taxFirstCheck,,,,,) = spog.spogData();

        // assert that tax was modified
        assertTrue(taxFirstCheck == newTaxValue, "Tax wasn't changed");
    }
}
