// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IERC20 } from "../../../lib/common/src/interfaces/IERC20.sol";
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
        IZeroGovernor.setEmergencyProposalThresholdRatio.selector,
        IZeroGovernor.setZeroProposalThresholdRatio.selector
    ];

    uint256[] internal _emergencyGovernorProposalIds;
    uint256[] internal _standardGovernorProposalIds;
    uint256[] internal _zeroGovernorProposalIds;

    string[] internal _registrarLists = ["earners", "earners_list_ignored", "minters", "validators"];

    address[] internal _emergencyGovernorTargets;
    uint256[] internal _emergencyGovernorValues;

    address[] internal _standardGovernorTargets;
    uint256[] internal _standardGovernorValues;

    address[] internal _zeroGovernorTargets;
    uint256[] internal _zeroGovernorValues;

    address[] internal _allowedCashTokens;

    mapping(uint256 proposalId => bool hasBeenSubmitted) internal _submittedProposals;
    mapping(uint256 proposalId => bytes proposalCallData) internal _submittedProposalsCallData;

    constructor(
        IRegistrar registrar_,
        IEmergencyGovernor emergencyGovernor_,
        IStandardGovernor standardGovernor_,
        IZeroGovernor zeroGovernor_,
        address[] memory allowedCashTokens_
    ) {
        _registrar = registrar_;

        _emergencyGovernor = emergencyGovernor_;
        _emergencyGovernorTargets.push(address(_emergencyGovernor));
        _emergencyGovernorValues.push(0);

        _standardGovernor = standardGovernor_;
        _standardGovernorTargets.push(address(_standardGovernor));
        _standardGovernorValues.push(0);

        _zeroGovernor = zeroGovernor_;
        _zeroGovernorTargets.push(address(_zeroGovernor));
        _zeroGovernorValues.push(0);

        _allowedCashTokens = allowedCashTokens_;
    }

    /* ============ Emergency Governor Proposals ============ */

    function emergencyGovernorAddToList(address proposer_, uint256 registrarListSeed_) external {
        console2.log("Start emergencyGovernorAddToList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if proposer is in the list
        if (_registrar.listContains(bytes32(bytes(list_)), proposer_)) {
            console2.log("Proposer is already in the list");
            return;
        }

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
        if (!_registrar.listContains(bytes32(bytes(list_)), accountToRemove_)) {
            console2.log("Account to remove is not in the list");
            return;
        }

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
        ) {
            console2.log("Account to remove is not in the list or account to add is already in the list");
            return;
        }

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
        if (_registrar.get(bytes32(bytes(key_))) == bytes32(bytes(value_))) {
            console2.log("Key value pair already exists");
            return;
        }

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
        console2.log("Start emergencyGovernorSetStandardProposalFee...");

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

    /* ============ Standard Governor Proposals ============ */

    function standardGovernorAddToList(address proposer_, uint256 registrarListSeed_) external {
        console2.log("Start standardGovernorAddToList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if proposer is in the list
        if (_registrar.listContains(bytes32(bytes(list_)), proposer_)) {
            console2.log("Proposer is already in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.addToList.selector, bytes32(bytes(list_)), proposer_),
            "Add proposer to list"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to add %s to %s list has already been submitted", proposer_, list_);
            return;
        }

        console2.log("Standard proposal %s to add %s to %s list created successfully!", proposalId_, proposer_, list_);
    }

    function standardGovernorRemoveFromList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_
    ) external {
        console2.log("Start standardGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list
        if (!_registrar.listContains(bytes32(bytes(list_)), accountToRemove_)) {
            console2.log("Account to remove is not in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.removeFromList.selector, bytes32(bytes(list_)), accountToRemove_),
            "Remove account from list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Standard proposal to remove %s from %s list has already been submitted",
                accountToRemove_,
                list_
            );
            return;
        }

        console2.log(
            "Standard proposal %s to remove %s from %s list created successfully!",
            proposalId_,
            accountToRemove_,
            list_
        );
    }

    function standardGovernorRemoveFromAndAddToList(
        address proposer_,
        uint256 registrarListSeed_,
        address accountToRemove_,
        address accountToAdd_
    ) external {
        console2.log("Start standardGovernorRemoveFromList...");
        registrarListSeed_ = bound(registrarListSeed_, 0, _registrarLists.length - 1);

        string memory list_ = _registrarLists[registrarListSeed_];

        // Return early if account to remove is not in the list or if account to add is already in the list
        if (
            !_registrar.listContains(bytes32(bytes(list_)), accountToRemove_) ||
            _registrar.listContains(bytes32(bytes(list_)), accountToAdd_)
        ) {
            console2.log("Account to remove is not in the list or account to add is already in the list");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IStandardGovernor.removeFromAndAddToList.selector,
                bytes32(bytes(list_)),
                accountToRemove_,
                accountToAdd_
            ),
            "Remove account from list and add new account to list"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Standard proposal to remove %s from %s list and add %s has already been submitted",
                accountToRemove_,
                list_,
                accountToAdd_
            );
            return;
        }

        console2.log(
            "Standard proposal to remove %s from %s list and add %s created successfully!",
            accountToRemove_,
            list_,
            accountToAdd_
        );
    }

    function standardGovernorSetKey(address proposer_, uint256 keySeed_, uint256 valueSeed_) external {
        console2.log("Start standardGovernorSetKey...");

        string memory key_ = _generateRandomString(keySeed_);
        string memory value_ = _generateRandomString(valueSeed_);

        // Return early if key value pair already exists
        if (_registrar.get(bytes32(bytes(key_))) == bytes32(bytes(value_))) {
            console2.log("Key value pair already exists");
            return;
        }

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.setKey.selector, bytes32(bytes(key_)), bytes32(bytes(value_))),
            "Set key value pair"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to set key %s and value %s has already been submitted", key_, value_);
            return;
        }

        console2.log(
            "Standard proposal %s to set key %s and value %s created successfully!",
            proposalId_,
            key_,
            value_
        );
    }

    function standardGovernorSetProposalFee(address proposer_, uint256 proposalFeeSeed_) external {
        console2.log("Start standardGovernorSetProposalFee...");

        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        uint256 proposalId_ = _standardGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IStandardGovernor.setProposalFee.selector, proposalFee_),
            "Set proposal fee"
        );

        if (proposalId_ == 0) {
            console2.log("Standard proposal to set proposal fee to %s has already been submitted", proposalFee_);
            return;
        }

        console2.log("Standard proposal %s to set proposal fee to %s created successfully!", proposalId_, proposalFee_);
    }

    /* ============ Zero Governor Proposals ============ */

    function zeroGovernorResetToPowerHolders(address proposer_) external {
        console2.log("Start zeroGovernorResetToPowerHolders...");

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.resetToPowerHolders.selector),
            "Reset to POWER holders"
        );

        if (proposalId_ == 0) {
            console2.log("Zero proposal to reset to POWER holders has already been submitted");
            return;
        }

        console2.log("Zero proposal %s to reset to POWER holders created successfully!", proposalId_);
    }

    function zeroGovernorResetToZeroHolders(address proposer_) external {
        console2.log("Start zeroGovernorResetToZeroHolders...");

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.resetToZeroHolders.selector),
            "Reset to ZERO holders"
        );

        if (proposalId_ == 0) {
            console2.log("Zero proposal to reset to ZERO holders has already been submitted");
            return;
        }

        console2.log("Zero proposal %s to reset to ZERO holders created successfully!", proposalId_);
    }

    function zeroGovernorSetCashToken(address proposer_, uint256 cashTokenSeed_, uint256 proposalFeeSeed_) external {
        console2.log("Start zeroGovernorSetCashToken...");
        cashTokenSeed_ = bound(cashTokenSeed_, 0, _allowedCashTokens.length - 1);

        address cashToken_ = _allowedCashTokens[cashTokenSeed_];
        uint256 proposalFee_ = _generateRandomProposalFee(proposalFeeSeed_);

        // Return early if cash token is already set
        if (_standardGovernor.cashToken() == cashToken_) {
            console2.log("Cash token is already set");
            return;
        }

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.setCashToken.selector, cashToken_, proposalFee_),
            "Set cash token"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set cash token to %s and proposal fee to %s has already been submitted",
                cashToken_,
                proposalFee_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set cash token to %s and proposal fee to %s created successfully!",
            proposalId_,
            cashToken_,
            proposalFee_
        );
    }

    function zeroGovernorSetEmergencyProposalThresholdRatio(
        address proposer_,
        uint256 emergencyProposalThresholdRatioSeed_
    ) external {
        console2.log("Start zeroGovernorSetEmergencyProposalThresholdRatio...");

        uint16 emergencyProposalThresholdRatio_ = _generateRandomThresholdRatio(emergencyProposalThresholdRatioSeed_);

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(
                IZeroGovernor.setEmergencyProposalThresholdRatio.selector,
                emergencyProposalThresholdRatio_
            ),
            "Set Emergency Proposal Threshold Ratio"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set Emergency Proposal Threshold Ratio to %s has already been submitted",
                emergencyProposalThresholdRatio_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set Emergency Proposal Threshold Ratio to %s created successfully!",
            proposalId_,
            emergencyProposalThresholdRatio_
        );
    }

    function zeroGovernorSetZeroProposalThresholdRatio(
        address proposer_,
        uint256 zeroProposalThresholdRatioSeed_
    ) external {
        console2.log("Start zeroGovernorSetZeroProposalThresholdRatio...");

        uint16 zeroProposalThresholdRatio_ = _generateRandomThresholdRatio(zeroProposalThresholdRatioSeed_);

        uint256 proposalId_ = _zeroGovernorPropose(
            proposer_,
            abi.encodeWithSelector(IZeroGovernor.setZeroProposalThresholdRatio.selector, zeroProposalThresholdRatio_),
            "Set Zero Proposal Threshold Ratio"
        );

        if (proposalId_ == 0) {
            console2.log(
                "Zero proposal to set Zero Proposal Threshold Ratio to %s has already been submitted",
                zeroProposalThresholdRatio_
            );
            return;
        }

        console2.log(
            "Zero proposal %s to set Zero Proposal Threshold Ratio to %s created successfully!",
            proposalId_,
            zeroProposalThresholdRatio_
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
        if (_emergencyGovernorProposalIds.length == 0) {
            console2.log("No Emergency proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovernorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Emergency proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

        // Return early if the proposal is not votable.
        if (state_ != IGovernor.ProposalState.Active) {
            console2.log("Emergency proposal %s is not votable...", proposalId_);
            return;
        }

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

            // Exit loop early if the proposal has been defeated or succeeded.
            if (state_ == IGovernor.ProposalState.Defeated || state_ == IGovernor.ProposalState.Succeeded) {
                console2.log("Emergency proposal %s has been defeated or succeeded...", proposalId_);
                return;
            }

            address account_ = accounts_[i];

            // Generate a random number between 0 and 99 (inclusive)
            uint8 support_ = (uint256(keccak256(abi.encodePacked(supportSeed_, account_))) % 100) % 2 == 0
                ? uint8(IBatchGovernor.VoteType.Yes)
                : uint8(IBatchGovernor.VoteType.No);

            vm.prank(account_);
            _emergencyGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Emergency proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );
        }
    }

    function voteOnStandardGovernorProposal(
        uint256 proposalIdSeed_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnStandardGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_standardGovernorProposalIds.length == 0) {
            console2.log("No Standard proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _standardGovernorProposalIds.length - 1);
        uint256 proposalId_ = _standardGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Standard proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , ) = _standardGovernor.getProposal(proposalId_);

        // Return early if the proposal is not votable.
        if (state_ != IGovernor.ProposalState.Active) {
            console2.log("Standard proposal %s is not votable...", proposalId_);
            return;
        }

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , ) = _standardGovernor.getProposal(proposalId_);

            // Exit loop early if the proposal has been defeated or succeeded.
            if (state_ == IGovernor.ProposalState.Defeated || state_ == IGovernor.ProposalState.Succeeded) {
                console2.log("Standard proposal %s has been defeated or succeeded...", proposalId_);
                return;
            }

            address account_ = accounts_[i];

            // Generate a random number between 0 and 99 (inclusive)
            uint8 support_ = (uint256(keccak256(abi.encodePacked(supportSeed_, account_))) % 100) % 2 == 0
                ? uint8(IBatchGovernor.VoteType.Yes)
                : uint8(IBatchGovernor.VoteType.No);

            vm.prank(account_);
            _standardGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Standard proposal %s",
                account_,
                support_ == 1 ? "Yes" : "No",
                proposalId_
            );
        }
    }

    function voteOnZeroGovernorProposal(
        uint256 proposalIdSeed_,
        uint256 supportSeed_,
        address[] memory accounts_
    ) external {
        console2.log("Start voteOnZeroGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_zeroGovernorProposalIds.length == 0) {
            console2.log("No Zero proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _zeroGovernorProposalIds.length - 1);
        uint256 proposalId_ = _zeroGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Zero proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

        // Return early if the proposal is not votable.
        if (state_ != IGovernor.ProposalState.Active) {
            console2.log("Zero proposal %s is not votable...", proposalId_);
            return;
        }

        for (uint256 i; i < accounts_.length; i++) {
            (, , state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

            // Exit loop early if the proposal has been defeated or succeeded.
            if (state_ == IGovernor.ProposalState.Defeated || state_ == IGovernor.ProposalState.Succeeded) {
                console2.log("Zero proposal %s has been defeated or succeeded...", proposalId_);
                return;
            }

            address account_ = accounts_[i];

            // TODO: should not be needed since we should return earlier if the proposal is not votable
            // Skip vote if the account has already voted on the proposal
            if (_zeroGovernor.hasVoted(proposalId_, account_)) {
                console2.log("%s has already voted on Zero proposal %s", account_, proposalId_);
                continue;
            }

            // Generate a random number between 0 and 99 (inclusive)
            uint8 support_ = (uint256(keccak256(abi.encodePacked(supportSeed_, account_))) % 100) % 2 == 0
                ? uint8(IBatchGovernor.VoteType.Yes)
                : uint8(IBatchGovernor.VoteType.No);

            vm.prank(account_);
            _zeroGovernor.castVote(proposalId_, support_);

            console2.log(
                "Account %s casted a %s vote on Zero proposal %s",
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
        if (_emergencyGovernorProposalIds.length == 0) {
            console2.log("No Emergency proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _emergencyGovernorProposalIds.length - 1);
        uint256 proposalId_ = _emergencyGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Emergency proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , , ) = _emergencyGovernor.getProposal(proposalId_);

        // Return early if the proposal is not executable.
        if (state_ != IGovernor.ProposalState.Succeeded) {
            console2.log("Emergency proposal %s is not executable...", proposalId_);
            return;
        }

        console2.log("Executing Emergency proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _emergencyGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Emergency proposal %s executed successfully!", proposalId_);

        delete _emergencyGovernorProposalIds[proposalIdSeed_];
    }

    function executeStandardGovernorProposal(uint256 proposalIdSeed_) external {
        console2.log("Start executeStandardGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_standardGovernorProposalIds.length == 0) {
            console2.log("No Standard proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _standardGovernorProposalIds.length - 1);
        uint256 proposalId_ = _standardGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Standard proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , ) = _standardGovernor.getProposal(proposalId_);

        // Return early if the proposal is not executable.
        if (state_ != IGovernor.ProposalState.Succeeded) {
            console2.log("Standard proposal %s is not executable...", proposalId_);
            return;
        }

        console2.log("Executing Standard proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _standardGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Standard proposal %s executed successfully!", proposalId_);

        delete _standardGovernorProposalIds[proposalIdSeed_];
    }

    function executeZeroGovernorProposal(uint256 proposalIdSeed_) external {
        console2.log("Start executeZeroGovernorProposal...");

        // Return early if no proposals have been queued.
        if (_zeroGovernorProposalIds.length == 0) {
            console2.log("No Zero proposals have been queued...");
            return;
        }

        proposalIdSeed_ = bound(proposalIdSeed_, 0, _zeroGovernorProposalIds.length - 1);
        uint256 proposalId_ = _zeroGovernorProposalIds[proposalIdSeed_];

        // Return early if the proposal has already been executed.
        if (proposalId_ == 0) {
            console2.log("Zero proposal %s has already been executed...", proposalId_);
            return;
        }

        (, , IGovernor.ProposalState state_, , , , , ) = _zeroGovernor.getProposal(proposalId_);

        // Return early if the proposal is not executable.
        if (state_ != IGovernor.ProposalState.Succeeded) {
            console2.log("Zero proposal %s is not executable...", proposalId_);
            return;
        }

        console2.log("Executing Zero proposal %s", proposalId_);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = _submittedProposalsCallData[proposalId_];

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);

        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(""));

        console2.log("Zero proposal %s executed successfully!", proposalId_);

        delete _zeroGovernorProposalIds[proposalIdSeed_];
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

        _emergencyGovernorProposalIds.push(proposalId_);
    }

    function _standardGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _standardGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        vm.prank(proposer_);
        proposalId_ = _standardGovernor.propose(
            _standardGovernorTargets,
            _standardGovernorValues,
            callDatas_,
            description_
        );

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _standardGovernorProposalIds.push(proposalId_);
    }

    function _zeroGovernorPropose(
        address proposer_,
        bytes memory callData_,
        string memory description_
    ) internal returns (uint256 proposalId_) {
        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = callData_;

        uint256 expectedProposalId_ = _zeroGovernor.hashProposal(callDatas_[0]);

        // Return early if proposal has already been submitted
        if (_submittedProposals[expectedProposalId_]) return 0;

        vm.prank(proposer_);
        proposalId_ = _zeroGovernor.propose(_zeroGovernorTargets, _zeroGovernorValues, callDatas_, description_);

        _submittedProposals[proposalId_] = true;
        _submittedProposalsCallData[proposalId_] = callDatas_[0];

        _zeroGovernorProposalIds.push(proposalId_);
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

    function _generateRandomThresholdRatio(uint256 seed_) internal returns (uint16) {
        return uint16(uint256(keccak256(abi.encodePacked(vm.getBlockTimestamp(), seed_))) % 10_000);
    }
}
