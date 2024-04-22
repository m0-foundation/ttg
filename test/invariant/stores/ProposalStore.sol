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

    /* ============ Emergency Governor Proposals ============ */

    function emergencyGovernorAddToList(address proposer_, uint256 registrarListSeed_) external {
        console2.log("Start emergencyGovernorAddToList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if proposer is in the list
        if (_registrar.listContains(bytes32(bytes(list_)), proposer_)) return;

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.addToList.selector, bytes32(bytes(list_)), proposer_),
            "Add proposer to list"
        );

        if (proposalId_ == 0) {
            console2.log("Emergency proposal to add %s to %s list has already been submitted", proposer_, list_);
            return;
        }

        console2.log("Emergency proposal %s to add %s to %s list created successfully!", proposalId_, proposer_, list_);
    }

    function emergencyGovernorRemoveFromList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_
    ) external {
        console2.log("Start emergencyGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list
        if (!_registrar.listContains(bytes32(bytes(list_)), accountToRemove_)) return;

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.removeFromList.selector, bytes32(bytes(list_)), accountToRemove_),
            "Remove account from list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to remove %s from %s list has already been submitted",
                accountToRemove_,
                list_
            );
            return;
        }

        console2.log(
            "Emergency proposal %s to remove %s from %s list created successfully!",
            proposalId_,
            accountToRemove_,
            list_
        );
    }

    function emergencyGovernorRemoveFromAndAddToList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_,
        address accountToAdd_
    ) external {
        console2.log("Start emergencyGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list or if account to add is already in the list
        if (
            !_registrar.listContains(bytes32(bytes(list_)), accountToRemove_) ||
            _registrar.listContains(bytes32(bytes(list_)), accountToAdd_)
        ) return;

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IEmergencyGovernor.removeFromAndAddToList.selector,
                bytes32(bytes(list_)),
                accountToRemove_,
                accountToAdd_
            ),
            "Remove account from list and add new account to list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to remove %s from %s list and add %s has already been submitted",
                accountToRemove_,
                list_,
                accountToAdd_
            );
            return;
        }

        console2.log(
            "Emergency proposal to remove %s from %s list and add %s created successfully!",
            accountToRemove_,
            list_,
            accountToAdd_
        );
    }

    function emergencyGovernorSetKey(address proposer_, uint256 keySeed_, uint256 valueSeed_) external {
        console2.log("Start emergencyGovernorSetKey...");

        string memory key_ = _generateRandomString(keySeed_);
        string memory value_ = _generateRandomString(valueSeed_);

        // Return early if key value pair already exists
        if (_registrar.get(bytes32(bytes(key_))) == bytes32(bytes(value_))) return;

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.setKey.selector, bytes32(bytes(key_)), bytes32(bytes(value_))),
            "Set key value pair"
        );

        if (proposalId_ == 0) {
            console2.log("Emergency proposal to set key %s and value %s has already been submitted", key_, value_);
            return;
        }

        console2.log(
            "Emergency proposal %s to set key %s and value %s created successfully!",
            proposalId_,
            key_,
            value_
        );
    }

    function emergencyGovernorSetStandardProposalFee(address proposer_, uint256 proposalFeeSeed_) external {
        console2.log("Start emergencyGovernorSetProposalFee...");

        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        uint256 proposalId_ = _emergencyGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IEmergencyGovernor.setStandardProposalFee.selector, proposalFee_),
            "Set Standard Governor proposal fee"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Emergency proposal to set Standard Governor proposal fee to %s has already been submitted",
                proposalFee_
            );
            return;
        }

        console2.log(
            "Emergency proposal %s to set Standard Governor proposal fee to %s created successfully!",
            proposalId_,
            proposalFee_
        );
    }

    /* ============ Vote on proposal ============ */

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

    /* ============ Execute proposal ============ */

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

    /* ============ Helpers ============ */

    function _emergencyGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _emergencyGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        vm.prank(proposer_);
        proposalId_ = _emergencyGovernor.propose(
            _emergencyGovernorTargets,
            _emergencyGovernorValues,
            callDatas_,
            description_
        );

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _emergencyGovenorProposalIds.push(proposalId_);
    }

    function _generateRandomProposalFee(uint256 seed_) internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), seed_))) % 1e18;
    }

    function _generateRandomString(uint256 seed_) internal view returns (string memory) {
        bytes memory characters_ = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        uint256 stringLength_ = 32;
        bytes memory randomString_ = new bytes(stringLength_);

        for (uint256 i = 0; i < stringLength_; i++) {
            // Generate a random index based on the seed
            randomString_[i] = characters_[uint256(keccak256(abi.encodePacked(seed_, i))) % characters_.length];
        }

        return string(randomString_);
    }
}
