// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { console2 } from "../../../lib/forge-std/src/Test.sol";

import { IGovernor } from "../../../src/abstract/interfaces/IGovernor.sol";
import { IBatchGovernor } from "../../../src/abstract/interfaces/IBatchGovernor.sol";

import { IRegistrar } from "../../../src/interfaces/IRegistrar.sol";
import { IEmergencyGovernor } from "../../../src/interfaces/IEmergencyGovernor.sol";
import { IStandardGovernor } from "../../../src/interfaces/IStandardGovernor.sol";
import { IZeroGovernor } from "../../../src/interfaces/IZeroGovernor.sol";

import { TestUtils } from "../../utils/TestUtils.sol";

contract ProposalStore is TestUtils {
    IRegistrar internal _registrar;

    IEmergencyGovernor internal _emergencyGovernor;
    IStandardGovernor internal _standardGovernor;
    IZeroGovernor internal _zeroGovernor;

    bytes4[] internal _emergencyGovernorPowerProposals = [
        IEmergencyGovernor.addToList.selector,
        IEmergencyGovernor.removeFromList.selector,
        IEmergencyGovernor.removeFromAndAddToList.selector,
        IEmergencyGovernor.setKey.selector,
        IEmergencyGovernor.setStandardProposalFee.selector
    ];

    bytes4[] internal _standardGovernorPowerProposals = [
        IStandardGovernor.addToList.selector,
        IStandardGovernor.removeFromList.selector,
        IStandardGovernor.removeFromAndAddToList.selector,
        IStandardGovernor.setKey.selector,
        IStandardGovernor.setProposalFee.selector
    ];

    bytes4[] internal _zeroGovernorZeroProposals = [
        IZeroGovernor.resetToPowerHolders.selector,
        IZeroGovernor.resetToZeroHolders.selector,
        IZeroGovernor.setCashToken.selector,
        IZeroGovernor.setZeroProposalThresholdRatio.selector,
        IZeroGovernor.setZeroProposalThresholdRatio.selector
    ];

    uint256[] internal _emergencyGovenorProposalIds;
    uint256[] internal _standardGovernorProposalIds;
    uint256[] internal _zeroGovernorProposalIds;

    string[] internal _registrarLists = ["earners", "earners_list_ignored", "minters", "validators"];
    address[] internal _emergencyGovernorTargets;
    uint256[] internal _emergencyGovernorValues;

    mapping(uint256 proposalId => bool hasBeenSubmitted) internal _submittedProposals;
    mapping(uint256 proposalId => bytes proposalCallData) internal _submittedProposalsCallData;

    constructor(
        IRegistrar registrar_,
        IEmergencyGovernor emergencyGovernor_,
        IStandardGovernor standardGovernor_,
        IZeroGovernor zeroGovernor_
    ) {
        _registrar = registrar_;

        _emergencyGovernor = emergencyGovernor_;
        _emergencyGovernorTargets.push(address(_emergencyGovernor));
        _emergencyGovernorValues.push(0);

        _standardGovernor = standardGovernor_;
        _zeroGovernor = zeroGovernor_;
    }

    function emergencyGovernorAddToList(uint256 addToListSeed_, address account_) external {
        console2.log("Start emergencyGovernorAddToList...");
        addToListSeed_ = bound(addToListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[addToListSeed_];

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(IEmergencyGovernor.addToList.selector, bytes32(bytes(list_)), account_);

        uint256 expectedProposalId_ = _emergencyGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return;

        vm.prank(account_);
        uint256 proposalId_ = _emergencyGovernor.propose(
            _emergencyGovernorTargets,
            _emergencyGovernorValues,
            callDatas_,
            "Add account to list"
        );

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _emergencyGovenorProposalIds.push(proposalId_);

        console2.log("Emergency proposal %s to add %s to %s list created successfully!", proposalId_, account_, list_);
    }

    function voteOnEmergencyGovernorProposal(
        uint256 proposalIdSeed_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnEmergencyGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_emergencyGovenorProposalIds.length == 0) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovenorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovenorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) return;

        (, , IGovernor.ProposalState state_, , , , ) = _emergencyGovernor.getProposal(proposalId_);

        // Return early if the proposal is not votable.
        if (state_ != IGovernor.ProposalState.Active) return;

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , ) = _emergencyGovernor.getProposal(proposalId_);

            // Exit loop early if the proposal has been defeated or succeeded.
            if (state_ == IGovernor.ProposalState.Defeated || state_ == IGovernor.ProposalState.Succeeded) return;

            address account_ = accounts_[i];

            // Generate a random number between 0 and 99 (inclusive)
            uint8 support_ = (uint256(keccak256(abi.encodePacked(supportSeed_, account_))) % 100) % 2 == 0
                ? uint8(IBatchGovernor.VoteType.Yes)
                : uint8(IBatchGovernor.VoteType.No);

            vm.prank(account_);
            _emergencyGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );
        }
    }

    function executeEmergencyGovernorProposal(uint256 proposalIdSeed_) external {
        console2.log("Start executeEmergencyGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_emergencyGovenorProposalIds.length == 0) return;

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovenorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovenorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) return;

        (, , IGovernor.ProposalState state_, , , , ) = _emergencyGovernor.getProposal(proposalId_);

        // Return early if the proposal is not executable.
        if (state_ != IGovernor.ProposalState.Succeeded) return;

        console2.log("Executing emergency proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _emergencyGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Emergency proposal %s executed successfully!", proposalId_);

        delete _emergencyGovenorProposalIds[proposalIdSeed_];
    }
}
