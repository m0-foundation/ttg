// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IComptroller } from "../../src/comptroller/IComptroller.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract SPOG_changeTax is SPOGBaseTest {
    uint256 internal newTaxValue;

    event TaxChanged(uint256 indexed tax);

    function setUp() public override {
        super.setUp();
        newTaxValue = deployScript.taxUpperBound();
    }

    function test_Revert_ChangeTaxWhenNotCalledFromGovernance() public {
        vm.expectRevert(IComptroller.CallerIsNotGovernor.selector);
        comptroller.changeTax(newTaxValue);
    }

    function test_Revert_WhenTaxValueIsOutOfTaxRangeBounds() public {
        uint256 outOfBoundsTaxValue = deployScript.taxUpperBound() + 1;

        address[] memory targets = new address[](1);
        targets[0] = address(comptroller);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("changeTax(uint256)", outOfBoundsTaxValue);
        string memory description = "Change tax variable in comptroller";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        // vote on proposal
        cash.approve(address(comptroller), tax);
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        vm.expectRevert(IComptroller.TaxOutOfRange.selector);
        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 tax = comptroller.tax();
        // assert that tax has not been modified
        assertFalse(tax == outOfBoundsTaxValue, "Tax should not have been changed");
    }

    function test_ChangeTaxViaProposalBySPOGGovernorVote() public {
        // create proposal to change variable in comptroller
        address[] memory targets = new address[](1);
        targets[0] = address(comptroller);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("changeTax(uint256)", newTaxValue);
        string memory description = "Change tax variable in comptroller";

        (bytes32 hashedDescription, uint256 proposalId) = getProposalIdAndHashedDescription(
            targets,
            values,
            calldatas,
            description
        );

        // vote on proposal
        cash.approve(address(comptroller), tax);
        governor.propose(targets, values, calldatas, description);

        // fast forward to an active voting period
        vm.roll(block.number + governor.votingDelay() + 1);

        // cast vote on proposal
        governor.castVote(proposalId, yesVote);
        // fast forward to end of voting period
        vm.roll(block.number + governor.votingPeriod() + 1);

        governor.execute(targets, values, calldatas, hashedDescription);

        uint256 tax = comptroller.tax();

        // assert that tax was modified
        assertTrue(tax == newTaxValue, "Tax wasn't changed");
    }
}
